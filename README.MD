The Hidden Name And Mail is a Bugzilla extension that adds the ability to hide users real details by providing fields for Hidden and Email, only visible by admins
## Installation
* Download the latest release.
* Unpack the download. This will create a directory called "HiddenNameAndMail".
* Move the "HiddenNameAndMail" directory into the "extensions" directory in your Bugzilla installation.
Go to your Bugzilla directory
Apply the patch and run checksetup.pl
```
patch -p0 -i extensions/HiddenNameAndMail/patch-4.x.diff
./checksetup.pl
```
