# AD-Lab-Generator
Tool for populating an Active Directory Lab with a randomized set of users and groups.

## About

This powershell tool was created to provide a way to populate an AD lab with randomized sets of groups and users for use in testing of other AD tools or scripts. It does not require the Active Directory Powershell module. 

In the default mode, a role-based access model is followed, and users are placed into a single "role group" such as "Sales" or "Engineering" which are then place into dummy "access groups". To make it more relavant to most real world AD setups, the users are also placed into a random number of access groups. The tool can also be run to create "clean roles" to emulate proper rbac or without roles to emulate no rbac.  

The tool will create randomized user names based on a configurable seed file called Names.txt and create groups defined in Groups.txt allowing for whatever localization or customization.

## Download
Relevant files are available as a .zip.

|Release|Link                |
|-------|--------------------|
|v1.0   |[AD-Lab-Generator.zip][AD-Lab-Generator-v1]|

[AD-Lab-Generator-v1]: https://github.com/KevOtt/AD-Lab-Generator/releases/download/v1.0/AD-Lab-Generator.zip

## How to Use

The script "Generate AD Lab" can be called from Powershell and will require that the full name of the target domain be specified (i.e. example.com). Optionally specify a number of users with "-NumberofUsers", default will be 30. To create users that are just placed into dummy access groups, run with the switch "-NoRoles".  To add only the role groups into access groups to emulate proper rbac, users are placed into access groups, run with the switch "CleanRoles". Running with "-ExportPasswords" will drop a text file to the script root with the passwords of the created users.

For now, the tool will only create all groups and users in a single OU or CN. All objects will be created in the Users Container by default; otherwise specify the Distinguished Name of an existing OU or CN for the argument "-TargetLocation" to create all objects in that location.

Note that this tool does not require the presence of the Active Directory Powershell module, but as of version 1.0 Powershell Core does not support the .Net assemblies utilized.

Example: 

`Powershell.exe & '.\Generate AD Lab.ps1' -Domain 'Example.com' -TargetLocation 'OU=Lab,DC=Example,DC=Com' -Verbose`


Configs\Names.txt can be modified with more, less, or different name seeds that are used to generate random user names. If you are generating many thousands of users, you will likely need to add additional seeds on top of the example data to avoid running into issues with lack of randomness. Groups names can be added or removed in Config\Groups.txt

## Screenshots

Example user & Example lab result:
<p align="center">
  <img src="/docs/Screenshots/ExampleResult.jpg" width="550" title="hover text">
</p>

## Future Versions

Plans for future versions include support for creating objects across multiple OUs automatically, more group nesting to better simulate most real-world AD environments, and the ability to create labs across multiple Domains in a forest.

## License

AD Lab Generator is licenced under the [MIT license][].

[MIT license]: https://github.com/KevOtt/AD-Lab-Generator/blob/master/LICENSE
