import struct,os,subprocess,shutil

DESKTOP='/Users/chuzu/Desktop'
PAYLOAD=f'{DESKTOP}/Payload'
STOCKS=f'{PAYLOAD}/Stocks.app/Stocks'

# 1. Clean extract
subprocess.run(['rm','-rf',PAYLOAD])
subprocess.run(['unzip','-o',f'{DESKTOP}/Amazon2.zip','-d',DESKTOP],capture_output=True)

# 2. Read
f=open(STOCKS,'rb');s=bytearray(f.read());f.close()
print(f'Stocks: {len(s)}B')

# 3. Patch ALL LoginViewController BOOL-returning methods to always return YES
# These are: 0x1000e2fdc, 0x1000e2fe4, 0x1000e2fec
# 0x1000e2fdc: mov w0,#0;ret -> mov w0,#1;ret
# 0x1000e2fe4: mov w0,#2;ret -> mov w0,#1;ret  
# 0x1000e2fec: mov w0,#1;ret -> already returns 1!
offs=[0xe2fdc, 0xe2fe4]  # file offsets for BOOL methods
for off in offs:
    s[off:off+4]=struct.pack('<I',0x52800020)  # mov w0, #1
print(f'Patched BOOL validators: always return YES')

# 4. Also patch viewDidLoad - make it return immediately
# This hides the login UI but the onAuthorized block still needs to be called
# Let's NOT patch viewDidLoad yet - just make validators return YES

# 5. Repack
cs=f'{PAYLOAD}/Stocks.app/_CodeSignature'
if os.path.exists(cs):shutil.rmtree(cs)

os.chdir(DESKTOP)
subprocess.run(['zip','-r','Amazon2_nokey.ipa','Payload/'],capture_output=True)
sz=os.path.getsize(f'{DESKTOP}/Amazon2_nokey.ipa')
print(f'Done: Amazon2_nokey.ipa ({sz/1024/1024:.0f}MB)')
print('Patches:')
print('  BOOL return methods -> always YES')
print('  _CodeSignature removed (TrollStore)')
