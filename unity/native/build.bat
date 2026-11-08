@echo off
rem Builds the destruction core into the Unity project (x64, MSVC /O2). No Godot, no godot-cpp.
for /f "usebackq delims=" %%i in (`"%ProgramFiles(x86)%\Microsoft Visual Studio\Installer\vswhere.exe" -latest -property installationPath`) do set VS=%%i
call "%VS%\VC\Auxiliary\Build\vcvars64.bat" >nul
cd /d "%~dp0"
if not exist build mkdir build
if not exist ..\Assets\Plugins\x86_64 mkdir ..\Assets\Plugins\x86_64
cl /nologo /O2 /Oi /GL /EHsc /std:c++17 /MT /LD /Fo:build\ kaiju_core.cpp kaiju_sim.cpp /link /LTCG /OUT:..\Assets\Plugins\x86_64\kaiju_core.dll /IMPLIB:build\kaiju_core.lib
