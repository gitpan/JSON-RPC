##############################################################################
package JSON::RPC::Server::FastCGI;
# Written by Faiz Kazi
use strict;
use CGI::Fast;
use JSON::RPC::Server; # for old Perl 5.005
use base qw(JSON::RPC::Server::CGI);

$JSON::RPC::Server::FastCGI::VERSION = '0.01';


sub new {
    JSON::RPC::Server::new(@_);
}


sub handle {
    my $self = shift;
    my $cgi;

    while ($cgi = new CGI::Fast) {
        $self->request( HTTP::Request->new($cgi->request_method, $cgi->url) );
        $self->{_cgi} = $cgi;
        $self->SUPER::handle();
    }

}


sub cgi {
    return $_[0]->{_cgi};
}


1;
__END__


