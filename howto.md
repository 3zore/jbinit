# At your own risk.

# howto  

## dependencies
- jailbroken device
- checkra1n 0.1337.0
- https://github.com/3zore/jbinit  
- https://github.com/3zore/PongoOS  

## prepare  
- ios side
```
mkdir -p /kbin /fs/orig
```

- macos side
```
scp -P {port} run.sh jbinit jbloader jb.dylib launchd root@localhost:/kbin/
```

- ios side
```
reboot
```

## booting  
- macos side
```
checkra1n -cpE
python3 scripts/boot.py -k build/checkra1n-kpf-pongo -d build/dtpatcher
```

If it worked, you can remove some folders on /System/Library/ with ssh ramdisk
