##############################################################################
# JSONRPC version 1.1
# http://json-rpc.org/wd/JSON-RPC-1-1-WD-20060807.html
##############################################################################

use strict;
use JSON::PP ();
use Carp ();

##############################################################################

package JSON::RPC::Client;

$JSON::RPC::Client::VERSION = '0.01';

use LWP::UserAgent;


BEGIN {
    for my $method (qw/uri ua json content_type version id allow_call status_line/) {
        eval qq|
            sub $method {
                \$_[0]->{$method} = \$_[1] if defined \$_[1];
                \$_[0]->{$method};
            }
        |;
    }
}



sub AUTOLOAD {
    my $self   = shift;
    my $method = $JSON::RPC::Client::AUTOLOAD;

    $method =~ s/.*:://;

    return if ($method eq 'DESTROY');

    return unless (exists $self->allow_call->{$method});

    my @params = @_;
    my $obj = {
        method => $method,
        params => (ref $_[0] ? $_[0] : [@_]),
    };

    my $ret = $self->call($self->uri, $obj);

    return ($ret and $ret->is_success) ? $ret->result : undef;
}


sub new {
    my $proto = shift;
    my $self  = bless {}, (ref $proto ? ref $proto : $proto);

    my $ua  = LWP::UserAgent->new(
        agent   => 'JSON::RPC::Client/' . $JSON::RPC::Client::VERSION . ' beta ',
        timeout => 10,
    );

    $self->ua($ua);
    $self->json( JSON::PP->new->allow_nonref->utf8 );
    $self->version('1.1');
    $self->content_type('application/json');

    return $self;
}


sub prepare {
    my ($self, $uri, $procedures) = @_;
    $self->uri($uri);
    $self->allow_call({ map { ($_ => 1) } @$procedures  });
}


sub call {
    my ($self, $uri, $obj) = @_;
    my $result;

    if ($uri =~ /\?/) {
       $result = $self->_get($uri);
    }
    else {
        Carp::croak "not hashref." unless (ref $obj eq 'HASH');
        $result = $self->_post($uri, $obj);
    }

    my $service = $obj->{method} =~ /^system\./;

    $self->status_line($result->status_line);

    if ($result->is_success) {

        return unless($result->content); # notification?

        if ($service) {
            return JSON::RPC::ServiceObject->new($result);
        }

        return JSON::RPC::ReturnObject->new($result);
    }
    else {
        return;
    }
}


sub _post {
    my ($self, $uri, $obj) = @_;
    my $json = $self->json;

    $obj->{version} ||= $self->{version} || '1.1';

    if ($obj->{version} eq '1.0') {
        delete $obj->{version};
        if (exists $obj->{id}) {
            $self->id($obj->{id}) if ($obj->{id}); # if undef, it is notification.
        }
        else {
            $obj->{id} = $self->id || ($self->id('JSON::RPC::Client'));
        }
    }
    else {
        $obj->{id} = $self->id if (defined $self->id);
    }

    my $content = $json->encode($obj);

    $self->ua->post(
        $uri,
        Content_Type   => $self->{content_type},
        Content        => $content,
        Accept         => 'application/json',
    );
}


sub _get {
    my ($self, $uri) = @_;
    $self->ua->get(
        $uri,
        Accept         => 'application/json',
    );
}



##############################################################################

package JSON::RPC::ReturnObject;

$JSON::RPC::ReturnObject::VERSION = $JSON::RPC::VERSION;

BEGIN {
    for my $method (qw/is_success content jsontext version/) {
        eval qq|
            sub $method {
                \$_[0]->{$method} = \$_[1] if defined \$_[1];
                \$_[0]->{$method};
            }
        |;
    }
}


sub new {
    my ($class, $obj) = @_;
    my $content = JSON::PP->new->decode($obj->content);

    my $self = bless {
        jsontext  => $obj->content,
        content   => $content,
    }, $class;

    $content->{error} ? $self->is_success(0) : $self->is_success(1);

    $content->{version} ? $self->version(1.1) : $self->version(0) ;

    $self;
}


sub is_error { !$_[0]->is_success; }

sub error_message {
    $_[0]->version ? $_[0]->{content}->{error}->{message} : $_[0]->{content}->{error};
}


sub result {
    $_[0]->{content}->{result};
}


##############################################################################

package JSON::RPC::ServiceObject;

use base qw(JSON::RPC::ReturnObject);


sub sdversion {
    $_[0]->{content}->{sdversion} || '';
}


sub name {
    $_[0]->{content}->{name} || '';
}


sub result {
    $_[0]->{content}->{summary} || '';
}



1;
__END__


=pod


=head1 NAME

JSON::RPC::Server - Perl implementation of JSON-RPC sever

=head1 SYNOPSIS

 use JSON::RPC::Client;
 
 my $client = new JSON::RPC::Client;
 my $url    = 'http://www.example.com/jsonrpc/API';
 
 my $callobj = {
    method  => 'sum',
    params  => [ 17, 25 ], # ex.) params => { a => 20, b => 10 } for JSON-RPC v1.1
 };
 
 my $res = $client->call($uri, $callobj);
 
 if($res) {
    if ($res->is_error) {
        print "Error : ", $res->error_message;
    }
    else {
        print $res->result;
    }
 }
 else {
    print $client->status_line;
 }
 
 
 $client->prepare($uri, ['sum', 'echo']);
 print $client->sum(10, 23);
 

=head1 DESCRIPTION

This is JSON-RPC Client.
See L<http://json-rpc.org/wd/JSON-RPC-1-1-WD-20060807.html>.

Gets perl object and convert to JSON data.

Sends request.

Gets response.

Converts JSON data to perl object.


=head1 JSON::RPC::Client

=head2 METHODS

=over

=item new

Creates new JSON::RPC::Client object.

=item call($uri, $procedure_object)

Requests to $uri with $procedure_object.
Reuest method is usually 'post'.
If $uri has query string, method is 'get'.

About 'GET' method,
see to L<http://json-rpc.org/wd/JSON-RPC-1-1-WD-20060807.html#GetProcedureCall>.

Return value is L</JSON::RPC::ReturnObject>.


=item prepare($uri, $arrayref_of_procedure)

Allow to call methods in contents of $arrayref_of_procedure.
Return value is a result part of JSON::RPC::ReturnObject.

 $client->prepare($uri, ['sum', 'echo']);
 my $res = $client->echo('foobar'); # $res is 'foobar'.

Currently, can't call method name same as built-in method.


=item version

Sets JSON-RPC protocol version.
1.1 by default.


=item id

Sets a request identifier.
In JSON-RPC 1.1, it is optoinal.

If you set C<version> 1.0 and don't set id,
the module sets 'JSON::RPC::Client'.


=item ua

Setter/getter to L<LWP::UserAgent> object.


=item json

Setter/getter to JSON coder object.
Default is L<JSON::PP>, likes this:

 $self->json( JSON::PP->new->allow_nonref->utf8 );


=item status_line

Returns status code;
After C<call> remote procedure, a status code is set.


=back


=head1 JSON::RPC::ReturnObject

=head2 METHODS

=over

=item is_success

=item is_error

=item error_message

=item result

=item content

=item jsontext

=item version

=back

=head1 JSON::RPC::ServiceObject


=head1 RESERVED PROCEDURE

When a client call a procedure (method) name 'system.foobar',
JSON::RPC::Server look up MyApp::system::foobar.

L<http://json-rpc.org/wd/JSON-RPC-1-1-WD-20060807.html#ProcedureCall>

L<http://json-rpc.org/wd/JSON-RPC-1-1-WD-20060807.html#ServiceDescription>

There is JSON::RPC::Server::system::describe for default response of 'system.describe'.


=head1 SEE ALSO

L<http://json-rpc.org/wd/JSON-RPC-1-1-WD-20060807.html>

L<http://json-rpc.org/wiki/specification>

=head1 AUTHOR

Makamaka Hannyaharamitu, E<lt>makamaka[at]cpan.orgE<gt>


=head1 COPYRIGHT AND LICENSE

Copyright 2007 by Makamaka Hannyaharamitu

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself. 

=cut


