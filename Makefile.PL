use ExtUtils::MakeMaker;

WriteMakefile(
   NAME => 'ServerControl-Extension-Redirector-Iptables',
   VERSION_FROM => 'lib/ServerControl/Extension/Redirector/Iptables.pm',
   PREREQ_PM => {'ServerControl' => '>0.90'},
   EXE_FILES => ['bin/servercontrol-redirector-iptables'],
   LICENSE => 'bsd'
);

