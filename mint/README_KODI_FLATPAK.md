# Kodi - install and config (with flatpak)

## Install Kodi flatpack
```
sudo flatpak -y install tv.kodi.Kodi
```



## German localization
Create userdata and addons dir if not exists:
```
mkdir -p ~/.var/app/tv.kodi.Kodi/data/userdata  ~/.var/app/tv.kodi.Kodi/data/addons
```
Download Config
```
# go to addons-dir
cd ~/.var/app/tv.kodi.Kodi/data/addons

# parse newest version of addon language.de_de
addonvers=$(wget -q https://mirrors.kodi.tv/addons/omega/resource.language.de_de/ -O - | egrep "resource.language.de_de-.+\.zip" | tail -n1 | cut -d\" -f2)

# download language.de_de
wget "https://mirrors.kodi.tv/addons/omega/resource.language.de_de/${addonvers}"

# unpack language.de_de
unzip resource.language.de_de-11.0.97.zip

# load config
wget https://raw.githubusercontent.com/egabosh/linux-setups/refs/heads/main/debian/kodi/kodi-settings/userdata/guisettings.xml -O ~/.var/app/tv.kodi.Kodi/data/userdata/guisettings.xml
```


## MySQL/MariaDB Client

Create userdata dir if not exists:
```
mkdir -p ~/.var/app/tv.kodi.Kodi/data/userdata
```
### Write config in advancedsettings.xml:
Edit tags DBHOSTNAME, DBPORT, DBUSER, DBPASSWORD
```
xed ~/.var/app/tv.kodi.Kodi/data/userdata/advancedsettings.xml
```
```
<advancedsettings>
  <videodatabase>
    <type>mysql</type>
    <host>DBHOSTNAME</host>
    <port>DBPORT</port>
    <user>DBUSER</user>
    <pass>DBPASSWORD</pass>
  </videodatabase> 
  <musicdatabase>
    <type>mysql</type>
    <host>DBHOSTNAME</host>
    <port>DBPORT</port>
    <user>DBUSER</user>
    <pass>DBPASSWORD</pass>
  </musicdatabase>
  <videolibrary>
    <importwatchedstate>true</importwatchedstate>
    <importresumepoint>true</importresumepoint>
  </videolibrary>
</advancedsettings>
```

## SFTP Client

Create userdata dir if not exists:
```
mkdir -p ~/.var/app/tv.kodi.Kodi/data/userdata
```
### Do SSH Keyexchange
If you do not yet have an ed25519 keypair (~/.ssh/id\_ed25519 does not exist):
```
ssh-keygen -t ed25519 -f ~/.ssh/id_ed25519 -P ""
```
Get Public key
```
cat ~/.ssh/id_ed25519.pub`
```
Then write the public-key to `/home/SFTPUSER/.ssh/authorized_keys` on the server (replace USER-ON-SERVER with yout user on server-side)

### Give the flatpak sandbox access to ~/ssh
```
flatpak --user override tv.kodi.Kodi --filesystem=~/.ssh
```

### Write config files
Edit tags DBHOSTNAME, DBPORT, DBUSER, DBPASSWORD
```
xed ~/.var/app/tv.kodi.Kodi/data/userdata/mediasources.xml
```
#### mediasources.xml
```
<mediasources>
    <network>
        <location id="0">sftp://SFTP-USER@SFTP-SERVER:SFTP-PORT/OPTIONAL_DIR</location>
    </network>
</mediasources>
```
#### sources.xml
```
xed ~/.var/app/tv.kodi.Kodi/data/userdata/sources.xml
```
```
<sources>
    <programs>
        <default pathversion="1"></default>
    </programs>
    <video>
        <default pathversion="1"></default>
        <source>
            <name>Filme</name>
            <path pathversion="1">sftp://SFTP-USER@SFTP-SERVER:SFTP-PORT/PATH_WITH_MOVIES</path>
            <allowsharing>true</allowsharing>
        </source>
        <source>
            <name>Serien</name>
            <path pathversion="1">sftp://SFTP-USER@SFTP-SERVER:SFTP-PORT/PATH_WITH_TVSHOWS</path>
            <allowsharing>true</allowsharing>
        </source>
    </video>
    <music>
        <default pathversion="1"></default>
        <source>
            <name>Musik</name>
            <path pathversion="1">sftp://SFTP-USER@SFTP-SERVER:SFTP-PORT/PATH_WITH_MUSIC</path>
            <allowsharing>true</allowsharing>
        </source>
    </music>
</sources>
```
#### passwords.xml
```
xed ~/.var/app/tv.kodi.Kodi/data/userdata/passwords.xml
```
```
<passwords>
    <path>
        <from pathversion="1">sftp://SFTP-USER@SFTP-SERVER/</from>
        <to pathversion="1">sftp://SFTP-USER@SFTP-SERVER:SFTP-PORT/</to>
    </path>
</passwords>
```
