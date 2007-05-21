##############################################################################
package JSON::RPC::Server::CGI;

use strict;
use CGI;
use Data::Dumper;

use base qw(JSON::RPC::Server);

$JSON::RPC::Server::CGI::VERSION = '0.01';

sub new {
    my $class = shift;
    my $self  = $class->SUPER::new();
    my $cgi   = $self->cgi;

    $self->request( HTTP::Request->new($cgi->request_method, $cgi->url) );
    $self->path_info($cgi->path_info);

    $self;
}


sub retrieve_json_from_post {
    my $json = $_[0]->cgi->param('POSTDATA');
=pod
    $_[0]->raise_error(
        status_code => 200,
        version     => '1.1',
        code        => 100,
        message     => "No JSON data.",
    );
=cut
    return $json;
}


sub retrieve_json_from_get {
    my $self   = shift;
    my $cgi    = $self->cgi;
    my $params = {};

    $self->version(1.1);

    for my $name ($cgi->param) {
        my @values = $cgi->param($name);
        $params->{$name} = @values > 1 ? [@values] : $values[0];
    }

    my $method = $cgi->path_info;

    $method =~ s/^\///;

    $self->json->encode({
        version => '1.1',
        method  => $method,
        params  => $params,
    });
}


sub response {
    my ($self, $response) = @_;
    print "Status: " . $response->code . "\015\012" . $response->headers_as_string("\015\012")
           . "\015\012" . $response->content;
}


sub cgi {
    $_[0]->{cgi} ||= new CGI;
}



1;
__END__
