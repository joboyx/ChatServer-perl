use strict;
use warnings;

use Socket;
use IO::Select;

use threads;
use threads::shared;


$|  = 1;

# The following variables should be set within init_webserver_extension
use vars qw/
 $port_listen
/;

init_webserver_extension();

local *S;

socket     (S, PF_INET   , SOCK_STREAM , getprotobyname('tcp')) or die "couldn't open socket: $!";
setsockopt (S, SOL_SOCKET, SO_REUSEADDR, 1);
bind       (S, sockaddr_in($port_listen, INADDR_ANY));
listen     (S, 5)                                               or die "don't hear anything:  $!";

my $ss = IO::Select->new();
$ss -> add (*S);


while(1) {
  my @connections_pending = $ss->can_read();
  foreach (@connections_pending) {
    my $fh;
    my $remote = accept($fh, $_);

    my($port,$iaddr) = sockaddr_in($remote);
    my $peeraddress = inet_ntoa($iaddr);
	if($peeraddress)
	{
		print $peeraddress;
	}
	else
	{
		print "\n";
	}
	my $t = threads->create(\&new_connection, $fh);
    $t->detach();
  }
}

sub extract_vars {
  my $line = shift;
  my %vars;

  foreach my $part (split '&', $line) {
    $part =~ /^(.*)=(.*)$/;

    my $n = $1;
    my $v = $2;
  
    $n =~ s/%(..)/chr(hex($1))/eg;
    $v =~ s/%(..)/chr(hex($1))/eg;
    $vars{$n}=$v;
  }

  return \%vars;
}

sub new_connection {
  my $fh = shift;

  binmode $fh;

  my %req;

  $req{HEADER}={}; 

  my $request_line = <$fh>;
  my $first_line = "";

  while ($request_line ne "\r\n") {
     unless ($request_line) {
       close $fh; 
     }

     chomp $request_line;

     unless ($first_line) {
       $first_line = $request_line;

      my @parts = split(" ", $first_line);
       if (@parts != 3) {
         close $fh;
       }

       $req{METHOD} = $parts[0];
       $req{OBJECT} = $parts[1];
     }
     else {
       my ($name, $value) = split(": ", $request_line);
       $name       = lc $name;
       $req{HEADER}{$name} = $value;
     }

     $request_line = <$fh>;
  }

  http_request_handler($fh, \%req);

  close $fh;
}

sub http_request_handler {
  my $fh     =   shift;
  my $req_   =   shift;
  my %req    =   %$req_;
  my %header = %{$req{HEADER}};

  # print $fh "content-length: ... \r\n";
  # print $fh "\r\n";
  # print $fh "<html><h1>hello</h1></html>";
  
  $req{OBJECT} =~ /(.*)\?(.*)=(.*)/;
  my $cmd = $1;
  my $var = $2;
  my $val = $3;
  if($val)
  {
	$val =~ s/\%(..)/chr(hex($1))/eg;
  }
  
  if($req{OBJECT} eq '/')
  {
    open(FILE, "index.html");
    my @html = <FILE>;
	close(FILE);
	
	print $fh "HTTP/1.0 200 OK\r\n";
    print $fh "Server: adp perl webserver\r\n";

    foreach my $line (@html)
    {
      print $fh $line;
    }
  }
  elsif($req{OBJECT} =~ "sendmsg")
  {
	open(LOG_FH, ">>log.txt");
	my @log = <LOG_FH>;
	
	# print $fh "$val<br>";
	print LOG_FH "$val\n";
	close(LOG_FH);
  }
  elsif($req{OBJECT} =~ "loadmsg")
  {
    open(LOG_FH, "log.txt");
    my @log = <LOG_FH>;
	close(LOG_FH);
	
    foreach my $line (@log)
    {
	  print $fh $line, "<br>";
	}
  }
  elsif($req{OBJECT} =~ "clear")
  {
    system("rm log.txt");
  }
  # print "\n";
  # print "Method: $req{METHOD}\n";
  # print "Object: $req{OBJECT}\n";
  print ": $req{OBJECT}\n";

  # foreach my $r (keys %header) {
    # print $r, " = ", $header{$r} , "\n";
  # }  
}

sub init_webserver_extension {
  $port_listen = 1234;
}

1;