# vim: set ts=3 sw=3 tw=0:
# vim: set expandtab:

package ServerControl::Extension::Redirector::Iptables;

# servercontrol --create --port-http=10080 --port-https=10443
# servercontrol-redirector-iptables --member=/i01 --member=/i02 --member=/i03 --redirect-http=80 --redirect-https=443

use strict;
use warnings;

our $VERSION = '0.5.0';

use ServerControl::Extension;
use Net::Interface;
use Data::Dumper;

use base qw(ServerControl::Extension);

__PACKAGE__->register('after_start', sub { shift->after_start(@_); });
__PACKAGE__->register('before_stop',   sub { shift->before_stop(@_); });


sub after_start {
   my ($class, $sc) = @_;

   my $args = ServerControl::Args->get;

   # only set/remove rules when active
   if(-f $args->{"path"} . "/.active") {
      print "Setting iptables rules\n";
      _set_rules();

      # remove old rules
      my @members = @{ $args->{"member"} };
      for my $member (@members) {
         next if($member eq $args->{"path"});
         chdir($member);
         system("./control --run-hook=before_stop");
      }

   }
}

sub before_stop {
   my ($class, $sc) = @_;

   print "Removing iptables rules\n";
   _set_rules(1);
}

sub _set_rules {
   my ($remove) = @_;
   my $args = ServerControl::Args->get;
   my @public_port_keys = grep { /^port-/ } keys %{$args};

   my @devs;
   for my $line (qx{ip l |grep -v SLAVE |grep BROADCAST}) {
      chomp $line;
      my ($dev) = ($line =~ m/: ([a-z0-9]+):/);
      push(@devs, Net::Interface->new($dev));
   }

   for my $dev (@devs) {
      my @ips_on_iface = ips_on_iface($dev);
      next if(scalar(@ips_on_iface) == 0);

      for my $port_key (@public_port_keys) {
         my $private_port_key = $port_key;
         $private_port_key =~ s/^port-/redirect-/;

         my $public_port  = $args->{$port_key};
         my $private_port = $args->{$private_port_key};

         my $cmd = "/sbin/iptables -t nat -A PREROUTING -i $dev -p tcp --dport $public_port -j REDIRECT --to-port $private_port";
         if($remove) {
            $cmd = "/sbin/iptables -t nat -D PREROUTING -i $dev -p tcp --dport $public_port -j REDIRECT --to-port $private_port";
         }

         system($cmd);

         for my $ip (@ips_on_iface) {
            $cmd = "/sbin/iptables -t nat -A OUTPUT -p tcp -d $ip --dport $public_port -j DNAT --to $ip:$private_port";
            if($remove) {
               $cmd = "/sbin/iptables -t nat -D OUTPUT -p tcp -d $ip --dport $public_port -j DNAT --to $ip:$private_port";
            }
            system($cmd);
         }
      }
   }
}

sub ip_to_iface {
   my $self = shift;
   my $ip = shift;
	
   my @intf = Net::Interface->interfaces();
   foreach my $if (@intf) {
      my @addr = $if->address();
      if(@addr) {
         if(Net::Interface::inet_ntoa($addr[0]) eq $ip) {
            return $if;
         }
      }
   }
}

sub ips_on_iface {
   my $if = shift;
   my @ips = ();
	
   my @addr = $if->address(Net::Interface::af_inet);
   if(@addr) {
      foreach my $a (@addr) {
         push(@ips, Net::Interface::inet_ntoa($a))
      }
   }
	
   return @ips;
}

1;
