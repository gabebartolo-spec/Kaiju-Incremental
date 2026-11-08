@echo off
rem Builds the destruction core into the Unity project (x64, MSVC /O2). No Godot, no godot-cpp.
call "C:\Program Files\Microsoft Visual Studio\2022\Community\VC\Auxiliary\Build\vcvars64.bat" >nul
cd /d "%~dp0"
if not exist build mkdir build
if not exist ..\Assets\Plugins\x86_64 mkdir ..\Assets\Plugins\x86_64
cl /nologo /O2 /Oi /GL /EHsc /std:c++17 /MT /LD /Fo:build\ kaiju_core.cpp /link /LTCG /OUT:..\Assets\Plugins\x86_64\kaiju_core.dll /IMPLIB:build\kaiju_core.lib
