"""Build a temporary XCTest target around the existing app, without changing its Xcode project."""
import argparse, json, os, pathlib, plistlib, socket, subprocess, tempfile, time, urllib.request
ROOT=pathlib.Path(__file__).resolve().parents[1]
parser=argparse.ArgumentParser(); parser.add_argument('--simulator',required=True); parser.add_argument('--only-testing'); args=parser.parse_args()
with tempfile.TemporaryDirectory(prefix='uniride-ui-') as scratch:
    scratch=pathlib.Path(scratch)
    with socket.socket() as listener:
        listener.bind(('127.0.0.1',0)); port=listener.getsockname()[1]
    url=f'http://127.0.0.1:{port}'
    environment=dict(os.environ,UNIRIDE_SMTP_HOST='',UNIRIDE_APNS_KEY_FILE='')
    api=subprocess.Popen(['python3',str(ROOT/'backend/server.py'),'--port',str(port),'--database',str(scratch/'test.sqlite3')],env=environment)
    try:
        for _ in range(50):
            try: urllib.request.urlopen(url+'/health',timeout=1).close(); break
            except OSError: time.sleep(.1)
        p=json.loads(subprocess.check_output(['plutil','-convert','json','-o','-',str(ROOT/'UniRide.xcodeproj/project.pbxproj')]))
        objects=p['objects']; project=objects[p['rootObject']]
        app=next(k for k,v in objects.items() if v.get('productType')=='com.apple.product-type.application')
        for key in objects[app]['fileSystemSynchronizedGroups']:
            objects[key]['path']=str(ROOT/'UniRide'); objects[key]['sourceTree']='<absolute>'
        for v in objects.values():
            if v.get('isa')=='XCBuildConfiguration' and v.get('buildSettings',{}).get('INFOPLIST_FILE'):
                v['buildSettings']['INFOPLIST_FILE']=str(ROOT/'UniRide/Info.plist')
        def add(n,value):
            key=f'AA00000000000000000000{n:02X}'; objects[key]=value; return key
        product=add(1,dict(isa='PBXFileReference',explicitFileType='wrapper.cfbundle',path='Verification.xctest',sourceTree='BUILT_PRODUCTS_DIR'))
        phases=[add(i,dict(isa=kind,buildActionMask='2147483647',files=[],runOnlyForDeploymentPostprocessing='0')) for i,kind in [(2,'PBXSourcesBuildPhase'),(3,'PBXFrameworksBuildPhase'),(4,'PBXResourcesBuildPhase')]]
        group=add(5,dict(isa='PBXFileSystemSynchronizedRootGroup',path=str(ROOT/'Tests/UI'),sourceTree='<absolute>'))
        settings=dict(PRODUCT_BUNDLE_IDENTIFIER='HMZ.UniRide.Verification',PRODUCT_NAME='$(TARGET_NAME)',GENERATE_INFOPLIST_FILE='YES',SWIFT_VERSION='5.0',IPHONEOS_DEPLOYMENT_TARGET='16.0',TARGETED_DEVICE_FAMILY='1,2',TEST_TARGET_NAME='UniRide',SDKROOT='iphoneos',SUPPORTED_PLATFORMS='iphoneos iphonesimulator',CODE_SIGN_STYLE='Automatic')
        configurations=[add(i,dict(isa='XCBuildConfiguration',name=name,buildSettings=settings)) for i,name in [(6,'Debug'),(7,'Release')]]
        configs=add(8,dict(isa='XCConfigurationList',buildConfigurations=configurations,defaultConfigurationIsVisible='0',defaultConfigurationName='Debug'))
        dependency=add(9,dict(isa='PBXTargetDependency',target=app))
        target=add(10,dict(isa='PBXNativeTarget',name='Verification',productName='Verification',productReference=product,productType='com.apple.product-type.bundle.ui-testing',buildConfigurationList=configs,buildPhases=phases,dependencies=[dependency],buildRules=[],fileSystemSynchronizedGroups=[group],packageProductDependencies=[]))
        project['targets'].append(target); objects[project['mainGroup']]['children'].append(group); objects[project['productRefGroup']]['children'].append(product)
        directory=scratch/'UniRide.xcodeproj'; (directory/'xcshareddata/xcschemes').mkdir(parents=True)
        plistlib.dump(p,open(directory/'project.pbxproj','wb'))
        def reference(identifier,name,filename): return f'<BuildableReference BuildableIdentifier="primary" BlueprintIdentifier="{identifier}" BuildableName="{filename}" BlueprintName="{name}" ReferencedContainer="container:UniRide.xcodeproj"/>'
        scheme=f'''<?xml version="1.0" encoding="UTF-8"?><Scheme version="1.3"><BuildAction parallelizeBuildables="YES" buildImplicitDependencies="YES"><BuildActionEntries><BuildActionEntry buildForTesting="YES" buildForRunning="YES" buildForProfiling="NO" buildForArchiving="NO" buildForAnalyzing="YES">{reference(app,'UniRide','UniRide.app')}</BuildActionEntry><BuildActionEntry buildForTesting="YES" buildForRunning="NO" buildForProfiling="NO" buildForArchiving="NO" buildForAnalyzing="YES">{reference(target,'Verification','Verification.xctest')}</BuildActionEntry></BuildActionEntries></BuildAction><TestAction buildConfiguration="Debug" selectedDebuggerIdentifier="Xcode.DebuggerFoundation.Debugger.LLDB" selectedLauncherIdentifier="Xcode.IDEFoundation.Launcher.LLDB" shouldUseLaunchSchemeArgsEnv="YES"><Testables><TestableReference skipped="NO">{reference(target,'Verification','Verification.xctest')}</TestableReference></Testables><EnvironmentVariables><EnvironmentVariable key="UNIRIDE_TEST_API_URL" value="{url}" isEnabled="YES"/></EnvironmentVariables></TestAction></Scheme>'''
        (directory/'xcshareddata/xcschemes/Verification.xcscheme').write_text(scheme)
        result=subprocess.run(['xcodebuild','-project',str(directory),'-scheme','Verification','-destination','platform=iOS Simulator,id='+args.simulator,'-derivedDataPath',str(scratch/'build'),'-parallel-testing-enabled','NO','CODE_SIGNING_ALLOWED=NO',*(['-only-testing:'+args.only_testing] if args.only_testing else []),'test'])
        raise SystemExit(result.returncode)
    finally:
        api.terminate(); api.wait(timeout=5)
