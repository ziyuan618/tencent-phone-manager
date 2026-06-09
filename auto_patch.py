import struct,os,subprocess,shutil

DESKTOP='/Users/chuzu/Desktop'
STOCKS=f'{DESKTOP}/Payload/Stocks.app/Stocks'

# Clean extract
subprocess.run(['rm','-rf',f'{DESKTOP}/Payload'])
subprocess.run(['unzip','-o',f'{DESKTOP}/Amazon2.zip','-d',DESKTOP],capture_output=True)

f=open(STOCKS,'rb');s=bytearray(f.read());f.close()

# S-TIER APPROACH: Replace LoginViewController string in the Storyboard nib
# The storyboard instantiates LoginViewController by name
# Main.storyboardc/UIViewController-BYZ-38-t0r.nib contains the class name

nib_path=f'{DESKTOP}/Payload/Stocks.app/Base.lproj/Main.storyboardc/UIViewController-BYZ-38-t0r.nib'
if os.path.exists(nib_path):
    with open(nib_path,'rb') as f:nib=bytearray(f.read())
    
    # In NIB files, class names are stored as:
    # [length byte][class name bytes]
    # Search for "LoginViewController" preceded by its length
    
    idx=nib.find(b'LoginViewController')
    if idx>0:
        # The byte before should be 19 (length of LoginViewController)
        len_byte=nib[idx-1]
        print(f'NIB: LoginViewController at 0x{idx:x}, length byte=0x{len_byte:x}')
        
        # Replace with HUDRootViewController (20 chars)
        # Actually let me use AppViewController (17 chars) to fit in 19
        new_name=b'AppViewController\x00\x00'
        assert len(new_name)==19
        
        nib[idx:idx+19]=new_name
        # Update length byte? Actually NIB uses length prefix
        # Let me just try without changing length
        with open(nib_path,'wb') as f:f.write(nib)
        print(f'NIB: LoginViewController -> AppViewController')
else:
    print('NIB not found - checking Contents')
    # List all nib files
    storyboard_dir=f'{DESKTOP}/Payload/Stocks.app/Base.lproj/Main.storyboardc' 
    for fn in os.listdir(storyboard_dir):
        fp=os.path.join(storyboard_dir,fn)
        print(f'  {fn}: {os.path.getsize(fp)}B')
        if fn.endswith('.nib'):
            with open(fp,'rb') as f:
                data=f.read()
                if b'LoginView' in data:
                    print(f'    CONTAINS LoginView!')
                    idx=data.find(b'LoginView')
                    print(f'    at 0x{idx:x}, context: {data[max(0,idx-5):idx+30]}')

# Also search the binary for LoginViewController OBJC_CLASS_REF
# and replace with HUDRootViewController OBJC_CLASS_REF
# From the otool output:
# HUDRootViewController name at 0x100145bcf
# LoginViewController name at 0x100145ca1
# These are in __objc_classname section

# Find the OBJC_CLASS_$_LoginViewController in the symbol table
lgn=s.find(b'_OBJC_CLASS_$_LoginViewController')
hrv=s.find(b'_OBJC_CLASS_$_HUDRootViewController')
print(f'_OBJC_CLASS_$_LoginViewController at 0x{lgn:x}')
print(f'_OBJC_CLASS_$_HUDRootViewController at 0x{hrv:x}')

# Actually, let me try renaming in the symbol table
if lgn>0:
    # The symbol entry points to the class structure
    # If I rename it, objc_getClass("LoginViewController") returns nil
    # But the caller still uses the string "LoginViewController"
    # This doesn't help unless I change the CALLER's string too

# TRUE SOLUTION: Replace ALL LoginViewController strings in the binary
# In __cstring, __objc_classname, symbol table, everywhere
count=0
idx=0
old=b'LoginViewController'
while True:
    idx=s.find(old,idx)
    if idx<0:break
    s[idx:idx+19]=b'SkipLoginViewCtlr\x00\x00'  # exactly 19 chars
    count+=1
    idx+=19
print(f'Replaced {count} occurrences of LoginViewController')

# Repack
cs=f'{DESKTOP}/Payload/Stocks.app/_CodeSignature'
if os.path.exists(cs):shutil.rmtree(cs)

os.chdir(DESKTOP)
subprocess.run(['zip','-r','Amazon2_skip.ipa','Payload/'],capture_output=True)
print(f'Done: Amazon2_skip.ipa ({os.path.getsize(f"{DESKTOP}/Amazon2_skip.ipa")/1024/1024:.0f}MB)')
