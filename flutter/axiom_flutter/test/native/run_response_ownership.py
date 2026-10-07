"""Run the unchanged production Dart IO adapter with a controlled C ABI fixture."""
from pathlib import Path
import os,shutil,subprocess,sys,tempfile
package=Path(__file__).resolve().parents[2]
dart=os.environ.get('DART','dart')
with tempfile.TemporaryDirectory(prefix='axiom-dart-ownership-') as temporary:
 root=Path(temporary);shutil.copytree(package/'lib',root/'lib');shutil.copytree(package/'test/native',root/'test/native')
 (root/'pubspec.yaml').write_text('name: axiom_flutter\nenvironment:\n  sdk: ">=3.8.0 <4.0.0"\ndependencies:\n  ffi: 2.1.4\n  ansicolor: 2.0.3\n')
 library=root/('libaxiom_runtime.dylib' if sys.platform=='darwin' else 'libaxiom_runtime.so')
 subprocess.run(['cc','-dynamiclib' if sys.platform=='darwin' else '-shared','-fPIC','-std=c11','-Wall','-Wextra','-Werror',str(root/'test/native/response_ownership.c'),'-o',str(library)],check=True)
 env=dict(os.environ)
 if sys.platform=='darwin':
  subprocess.run(['codesign','--force','--sign','-',str(library)],check=True);env['DYLD_INSERT_LIBRARIES']=str(library)
 else:env['LD_LIBRARY_PATH']=str(root)
 subprocess.run([dart,'pub','get'],cwd=root,env=os.environ,check=True)
 subprocess.run([dart,'test/native/response_ownership.dart'],cwd=root,env=env,check=True,timeout=30)
