# If you hate passwords
If the password prompts are annoying and you don't care about the loss of security, you can disable passwords for administrative tasks

## sudo without password
```
echo '%adm ALL=(ALL) NOPASSWD:ALL' | sudo tee /etc/sudoers.d/adm
sudo chmod 640 /etc/sudoers.d/adm
```

## graphical admin actions without password
```
echo '/* Allow members of the adm group to execute any actions
 * without password authentication, similar to "sudo NOPASSWD:"
 */
polkit.addRule(function(action, subject) {
    if (subject.isInGroup("adm")) {
        return polkit.Result.YES;
    }
});' | sudo tee /etc/polkit-1/rules.d/adm.rules
sudo chmod 644 /etc/polkit-1/rules.d/adm.rules
```
## Additional deactivate keystore passwords prompts on autologin
I strongly recommend encrypting the hard disks if you want to turn this off to reduce the security loss
- search seahorse (passwords and keys) in the star menu and start it
- right click on default keyring (only exists if you use the keyring) -> Change Password
- leave the field for the new passwords empty.
- Accept passwords to be stored unencrypted
