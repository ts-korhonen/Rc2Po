del *.po /q
for /f %%f in ('dir /b *.rc') do rc2po en-us.rc %%f