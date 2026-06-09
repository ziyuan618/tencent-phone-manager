import struct,subprocess,os

DESKTOP='/Users/chuzu/Desktop'
STOCKS=f'{DESKTOP}/Payload/Stocks.app/Stocks'

subprocess.run(['rm','-rf',f'{DESKTOP}/Payload'])
subprocess.run(['unzip','-o',f'{DESKTOP}/Amazon2.zip','-d',DESKTOP],capture_output=True)

f=open(STOCKS,'rb');s=bytearray(f.read());f.close()

# ARM64: load _onAuthorized block, call it, return
code=struct.pack('<8I',
    0xA9BF7BFD,   # stp x29,x30,[sp,#-0x10]!
    0x910003FD,   # mov x29,sp
    0xF9400808,   # ldr x8,[x0,#0x10]
    0xB4000108,   # cbz x8,+2
    0xAA0803F0,   # mov x16,x8
    0xD63F0200,   # blr x16
    0xA8C17BFD,   # ldp x29,x30,[sp],#0x10
    0xD65F03C0    # ret
)

# Overwrite viewDidLoad at file offset 0xe2ff4
s[0xe2ff4:0xe2ff4+32]=code
# NOP the rest (was 0x160 bytes, fill with NOPs)
for i in range(32,0x160,4):s[0xe2ff4+i:0xe2ff4+i+4]=struct.pack('<I',0xD503201F)

f=open(STOCKS,'wb');f.write(s);f.close()
print(f'Patched viewDidLoad: auto-call onAuthorized ({len(s)}B)')

# Verify the patch
f=open(STOCKS,'rb');v=f.read();f.close()
check=v[0xe2ff4:0xe2ff4+8]
expected=struct.pack('<2I',0xA9BF7BFD,0x910003FD)
if check==expected:
    print('VERIFIED: patch applied correctly')
else:
    print(f'ERROR: got {check.hex()} expected {expected.hex()}')
    exit(1)

subprocess.run(['rm','-rf',f'{DESKTOP}/Payload/Stocks.app/_CodeSignature'])
os.chdir(DESKTOP)
subprocess.run(['zip','-r','Amazon2_auto.ipa','Payload/'],capture_output=True)
print(f'Done: Amazon2_auto.ipa ({os.path.getsize(f"{DESKTOP}/Amazon2_auto.ipa")/1024/1024:.0f}MB)')
