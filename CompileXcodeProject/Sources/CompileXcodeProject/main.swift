import PaversFRP
import SwiftShell
import Foundation

enum Argument: String {
  case project
  case target
  case workspace
  case buildDir
}

guard
let projectArg = main.arguments.findFirst({$0.hasPrefix(Argument.project.rawValue) && $0.contains("=")}),
let targetArg = main.arguments.findFirst({$0.hasPrefix(Argument.target.rawValue) && $0.contains("=")}),
  let buildDirArg = main.arguments.findFirst({$0.hasPrefix(Argument.buildDir.rawValue) && $0.contains("=")}),
  let workspaceArg = main.arguments.findFirst({$0.hasPrefix(Argument.workspace.rawValue) && $0.contains("=")}) else {
    exit(errormessage: "Not enough arguments", errorcode: -1)
}

guard
let projectName = projectArg.split("=").last,
let targetName = targetArg.split("=").last,
let workspacePath = workspaceArg.split("=").last,
  let buildDir = buildDirArg.split("=").last else {
    exit(errormessage: "argument format ill-formed", errorcode: -2)
}
print("projectName: \(projectName)")
print("targetName: \(targetName)")
print("workspacePath: \(workspacePath)")
print("buildDir: \(buildDir)")
//let projectName = "QWSDK"
//let targetName = "QWSDKUI"
//let workspacePath = "/Users/keith/QWSDK/QWSDK.xcworkspace"
//let buildDir = "/Users/keith/QWSDKBuild"

let configuration = "release"
let executablePath = "\(targetName).framework/\(targetName)"
let fullProductName = "\(targetName).framework"

func prepareDir(_ dir: String) -> Bool {
  let cleanBuildDir = run("rm", "-rf", dir)
  guard cleanBuildDir.succeeded else {
    let errorMsg = cleanBuildDir.error?.description ?? "Failed to clean Build Dir"
    print(errorMsg)
    return false
  }
  
  let createBuildDir = run("mkdir", "-p", dir)
  guard createBuildDir.succeeded else {
    let errorMsg = createBuildDir.error?.description ?? "Failed to create Build Dir"
    print(errorMsg)
    return false
  }
  
  return true
}

guard prepareDir(buildDir) else {
  exit(errormessage: "Cannot prepare \(buildDir)", errorcode: 1)
}

//let logFilePath = "\(buildDir)/build.log"
//guard Files.createFile(atPath: logFilePath, contents: nil, attributes: nil) else {
//  exit(errormessage: "Cannot create log file", errorcode: 2)
//}
//
//let logFile = FileHandle(forWritingAtPath: logFilePath)

/*
 ARM_SDK_DIR="${BUILD_DIR}/${CONFIGURATION}-iphoneos"
 X86_SDK_DIR="${BUILD_DIR}/${CONFIGURATION}-iphonesimulator"
 UNIVERSAL_OUTPUTFOLDER="${BUILD_DIR}/${CONFIGURATION}-universal"
 */

let armSDKDir = "\(buildDir)/\(configuration)-iphoneos"
let x86SDKDir = "\(buildDir)/\(configuration)-iphonesimulator"
let universalSDKDir = "\(buildDir)/\(configuration)-universal"

/*
 echo "Building for iPhoneSimulator"
 xcodebuild -workspace "${WORKSPACE_PATH}" -scheme "${TARGET_NAME}" -configuration ${CONFIGURATION} -sdk iphonesimulator -destination 'platform=iOS Simulator,name=iPhone 8 Plus' ARCHS='i386 x86_64' BUILD_DIR="${BUILD_DIR}" BUILD_ROOT="${BUILD_ROOT}" clean build
 RESULT=$?
 if [[ $RESULT != 0 ]] ; then
 exit 1
 fi
 */

print("Building for iPhoneSimulator")
do {
  try runAndPrint("xcodebuild",
                  "-workspace", workspacePath,
                  "-scheme", targetName,
                  "-configuration", configuration,
                  "-sdk", "iphonesimulator",
                  "-destination", "platform=iOS Simulator,name=iPhone 8 Plus",
                  "ARCHS=i386 x86_64",
                  "BUILD_DIR=\(buildDir)",
    "BUILD_ROOT=\(buildDir)",
    "clean", "build")}
catch {
  let msg = error.localizedDescription
  print(msg)
  exit(errormessage: msg, errorcode: 3)
}

/*
 echo "Building for iPhone"
 xcodebuild -workspace "${WORKSPACE_PATH}" -scheme "${TARGET_NAME}" -configuration ${CONFIGURATION} -sdk iphoneos -destination generic/platform=iOS ARCHS='armv7 arm64' BUILD_DIR="${BUILD_DIR}" BUILD_ROOT="${BUILD_ROOT}" clean build
 RESULT=$?
 if [[ $RESULT != 0 ]] ; then
 exit 1
 fi
 */

print("Building for iPhone")
do {
  try runAndPrint("xcodebuild",
                  "-workspace", "\(workspacePath)",
    "-scheme", "\(targetName)",
    "-configuration", "\(configuration)",
    "-sdk", "iphoneos",
    "-destination", "generic/platform=iOS",
    "ARCHS=armv7 arm64",
    "BUILD_DIR=\(buildDir)",
    "BUILD_ROOT=\(buildDir)",
    "clean", "build")}
catch {
  let msg = error.localizedDescription
  print(msg)
  exit(errormessage: msg, errorcode: 3)
}

print("Build x86 and arm succeeded!")

guard prepareDir(universalSDKDir) else {
  exit(errormessage: "Cannot prepare \(universalSDKDir)", errorcode: 4)
}

print("Copying to output folder")

/*cp -R "${ARM_SDK_DIR}/${FULL_PRODUCT_NAME}" "${UNIVERSAL_OUTPUTFOLDER}/"*/
let copyProductToOutputFolder = main.run(bash: "cp -R '\(armSDKDir)/\(fullProductName)' '\(universalSDKDir)/'")
guard copyProductToOutputFolder.succeeded else {
  let errorMsg = copyProductToOutputFolder.error?.description ?? "Failed to copy Product to Universal Dir"
  print(errorMsg)
  exit(errormessage: errorMsg, errorcode: 7)
}


/*
 # Step 2. Copy Swift modules from iphonesimulator build (if it exists) to the copied framework directory
 SIMULATOR_SWIFT_MODULES_DIR="${X86_SDK_DIR}/${TARGET_NAME}.framework/Modules/${TARGET_NAME}.swiftmodule/."
 if [ -d "${SIMULATOR_SWIFT_MODULES_DIR}" ]; then
 cp -R "${SIMULATOR_SWIFT_MODULES_DIR}" "${UNIVERSAL_OUTPUTFOLDER}/${TARGET_NAME}.framework/Modules/${TARGET_NAME}.swiftmodule"
 fi
 */

let simulatorSwiftModulesDir = "\(x86SDKDir)/\(targetName).framework/Modules/\(targetName).swiftmodule"

if let moduleFiles = try? Files.contentsOfDirectory(atPath: simulatorSwiftModulesDir), moduleFiles.isEmpty == false {
  main.run(bash: "cp -R \(simulatorSwiftModulesDir)/. \(universalSDKDir)/\(targetName).framework/Modules/\(targetName).swiftmodule")
}

/*
 # Step 3. Create universal binary file using lipo and place the combined executable in the copied framework directory
 echo "Combining executables"
 lipo -create -output "${UNIVERSAL_OUTPUTFOLDER}/${EXECUTABLE_PATH}" "${X86_SDK_DIR}/${EXECUTABLE_PATH}" "${ARM_SDK_DIR}/${EXECUTABLE_PATH}"
 
 RESULT=$?
 if [[ $RESULT != 0 ]] ; then
 exit 1
 fi
 
 */

print("Combining executables")
let lipo = main.run(bash: "lipo -create -output \(universalSDKDir)/\(executablePath) \(x86SDKDir)/\(executablePath) \(armSDKDir)/\(executablePath)")
guard lipo.succeeded else {
  let errorMsg = lipo.error?.description ?? "Failed to copy Product to Universal Dir"
  print(errorMsg)
  exit(errormessage: errorMsg, errorcode: 8)
}

print("Succeeded to build. ^v^ ")





