"""Resolve separate firmware EGL/GLES/GBM libraries by ELF ABI, without loading them.

Produces hints for a SYSTEM-userspace profile. These paths must not be injected
into a different private glibc without a separate ABI/dependency check.
"""
from pathlib import Path
import argparse,json,os,struct,tempfile

def elf_arch(path):
 try:
  with Path(path).open('rb') as f:b=f.read(20)
 except OSError:return None
 if len(b)<20 or b[:4]!=b'\x7fELF' or b[5]!=1:return None
 machine=struct.unpack_from('<H',b,18)[0]
 if b[4]==2 and machine==183:return 'aarch64'
 if b[4]==1 and machine==40:return 'armhf'
 return None

def search_dirs(architecture,root=Path('/')):
 names=(['usr/lib/aarch64-linux-gnu','lib/aarch64-linux-gnu','usr/lib64','lib64','usr/trimui/lib'] if architecture=='aarch64' else ['usr/lib/arm-linux-gnueabihf','lib/arm-linux-gnueabihf','usr/lib32','lib32'])
 names+=['usr/lib','lib','usr/local/lib']
 return [root/n for n in names]

def resolve(architecture,root=Path('/'),hints=None):
 hints=hints or {};directories=search_dirs(architecture,root)
 def choose(names,hint=None):
  if hint and elf_arch(hint)==architecture:return str(Path(hint).resolve())
  for d in directories:
   for name in names:
    p=d/name
    if elf_arch(p)==architecture:return str(p.resolve())
  return None
 # A PowerVR/Mesa EGL library is not a GLES or GBM implementation. Keep the
 # three roles separate even where a particular Mali build combines them.
 egl=choose(['libEGL.so.1','libEGL.so'],hints.get('egl'))
 gles=choose(['libGLESv2.so.2','libGLESv2.so'],hints.get('gles'))
 gbm=choose(['libgbm.so.1','libgbm.so'],hints.get('gbm'))
 return {'architecture':architecture,'egl':egl,'gles':gles,'gbm':gbm,
         'status':'candidate' if egl and gles else 'missing-firmware-graphics',
         'userspace':'system-only','graphics_context_tested':False,
         'astc':'unknown','gles_version':'unknown'}

def aliases(selection,directory):
 directory=Path(directory)
 if not directory.is_dir() or any(directory.iterdir()):raise ValueError('Use a new empty private temporary directory.')
 if selection['status']!='candidate':raise ValueError('Firmware EGL/GLES were not found for this ABI.')
 roles={'egl':['libEGL.so','libEGL.so.1'],'gles':['libGLESv2.so','libGLESv2.so.2'],'gbm':['libgbm.so','libgbm.so.1']}
 for role,names in roles.items():
  if selection[role]:
   for name in names:(directory/name).symlink_to(selection[role])

def main():
 p=argparse.ArgumentParser(description=__doc__);p.add_argument('--architecture',choices=['armhf','aarch64'],required=True);p.add_argument('--aliases-in-empty-dir');a=p.parse_args()
 result=resolve(a.architecture,hints={'egl':os.environ.get('SDL_VIDEO_EGL_DRIVER'),'gles':os.environ.get('SDL_VIDEO_GL_DRIVER')})
 if a.aliases_in_empty_dir:aliases(result,a.aliases_in_empty_dir)
 print(json.dumps(result,indent=2))
 raise SystemExit(0 if result['status']=='candidate' else 9)

if __name__=='__main__':main()
