package Test::Fluentd;
use 5.008_001;
use strict;
use warnings;
use Class::Accessor::Lite;

our $VERSION = '0.02';

my %DEFAULTS = (
    options                         => undef,
    base_dir                        => '',
    input_txt                       => undef,
    fluent_log                      => undef,
    fluent_conf                     => undef,
    fluent_conf_file                => 'fluent.conf',
    interval_time_after_start       => 3 ,
    interval_time_before_shutdown   => 3 ,
    interval_time_after_shutdown    => 3 ,
    pid                             => undef,
);

Class::Accessor::Lite->mk_accessors(keys %DEFAULTS);

sub new {
    my $class = shift;
    bless {
        %DEFAULTS,
        @_ == 1 ? %{ $_[0] } : @_,
    }, $class;
}

sub run{
    my ($self)  = @_;
    my $fluent_conf_dir = $self->get_log_file('fluent_conf_file');
    if($self->fluent_conf){
        die 'exists fluent conf!' if -f $fluent_conf_dir;
        open my $fh , '>' , $fluent_conf_dir or die 'cant open file !';
        print $fh $self->fluent_conf;
        close $fh;
    }
    my $fluent_log_dir = $self->get_log_file('fluent_log');
    my $input_txt = $self->get_log_file('input_txt');

    my $pid = fork;
    
    my $base_dir = "./";
    open my $logfh, '>>', $fluent_log_dir
        or die 'failed to create log file:' . $fluent_log_dir . ":$!";

    open my $outputfh, '>>', $input_txt
        or die 'failed to input log file:' .$input_txt  . ":$!";

    if($pid == 0){
        open STDOUT, '>&', $logfh or die "dup(2) failed:$!";
        open STDERR, '>&', $logfh or die "dup(2) failed:$!";
        exec('fluentd -c ' . $fluent_conf_dir);
        exit;
    }else{
        open STDOUT, '>&', $outputfh or die "dup(2) failed:$!";
        open STDERR, '>&', $outputfh or die "dup(2) failed:$!";
        $self->pid($pid);
        print "wait starting Fluentd\n";
        sleep $self->interval_time_after_start;
    }
}

sub stop{
    my ($self)  = @_;
    unless($self->pid){
        return;
    }
    warn "kill: " . $self->pid;
    sleep $self->interval_time_before_shutdown;
    kill 'TERM' , $self->pid;
    sleep $self->interval_time_after_shutdown;
    print "wait finish Fluentd\n";
    $self->pid(undef);

    if($self->fluent_conf){
        my $fluent_conf_dir = $self->get_log_file('fluent_conf_file');
        system "rm $fluent_conf_dir";
    }
}

sub get_log_file{
    my ($self , $file)  = @_;
    my $file_name =  $self->$file;
    unless($file_name =~ m{^/|^\.}){
        return $self->base_dir . $file_name;
    }
    return $file_name;
}

sub remove_input_txt{
    my ($self)  = @_;
    my $input_txt = $self->get_log_file('input_txt');
    system "rm $input_txt";
}

sub DESTROY {
    my $self = shift;
    $self->stop;
}



1;
__END__

=head1 NAME

Test::Fluentd - test module for fluentd

=head1 VERSION

Test::Fluentd version 0.01.

=head1 SYNOPSIS

    use Test::Fluentd;
    
    my $tf = Test::Fluentd->new(
        input_txt =>  '/var/log/access.log',
        fluent_log => '/var/log/test_fluent_log/fluent_log.txt' ,
        fluent_conf_file => '/etc/fluent.conf' ,
    );
    $tf->run;
    # output log
    print join("\t" , ($user_id , time)) . "\n";
    $tf->stop;

=head1 DESCRIPTION

Test::Fluentd automatically sets up a fluentd instance, and destroys it when the perl script exists.

=head1 INTERFACE

=head2 Read fluent config from file
    
    # read from /etc/fluent.conf
    # path /var/log/access.log
    # format /^(?<user_id>\d+)\t(?<time>\d+?)$/
    
    my $tf = Test::Fluentd->new(
        input_txt =>  '/var/log/access.log',
        fluent_log => '/var/log/test_fluent_log/fluent_log.txt' ,
        fluent_conf_file => '/etc/fluent.conf' ,
    );
    $tf->run;
    # output log
    print join("\t" , ($user_id , time)) . "\n";
    $tf->stop;

=head2 Read fluent config from string value

    # read from arguments
    my $config_string = <<'EOS';
    <source>
      type tail
      path /var/log/access.log
      pos_file /tmp/pos.pos
      tag hoge
      format /^(?<user_id>\d+)\t(?<time>\d+?)$/
    </source>
    <match hoge>
      type file
      path /var/log/fluent/output.log
    </match>
    EOS
    
    my $tf = Test::Fluentd->new(
        input_txt =>  '/var/log/access.log',
        fluent_log => '/var/log/test_fluent_log/fluent_log.txt' ,
        fluent_conf_file => '/tmp/fluent.conf' ,
        fluent_conf => $config_string ,
    );

    # create temporary file  /tmp/fluent.conf
    # die if exists /tmp/fluent.conf
    $tf->run;
    # output log
    print join("\t" , ($user_id , time)) . "\n";

    $tf->stop;
    # delete temporary file /tmp/fluent.conf when $tf->stop

=head2 Functions

=head3 new
    
    # This is combined with the head of each file input.txt , fluent.log , fluent_conf_file
    base_dir                        => '',
    # output print/warn log
    input_txt                       => undef,
    # output fluentd log
    fluent_log                      => undef,
    # set string fluent config 
    fluent_conf                     => undef,
    # set fluent config / set temporary fluent config file
    fluent_conf_file                => 'fluent.conf',
    # sleep time for launch fluentd 
    interval_time_after_start       => 3 ,
    # sleep time for before stop fluentd 
    # wait for flush_interval
    interval_time_before_shutdown   => 3 ,
    # sleep time for after stop fluentd 
    # wait for output file 
    interval_time_after_shutdown    => 3 ,

=head3 run

    launch fluentd

=head3 stop

    stop fluentd and delete temporary fluent config file if you load config from string.

=head3 remove_input_txt

    delete input_txt file.

=head1 DEPENDENCIES

Perl 5.8.1 or later.

=head1 BUGS

All complex software has bugs lurking in it, and this module is no
exception. If you find a bug please either email me, or add the bug
to cpan-RT.

=head1 SEE ALSO

L<Test::Memcached>

=head1 AUTHOR

Shinichiro Sato E<lt>s2otsa59@gmail.comE<gt>

=head1 LICENSE AND COPYRIGHT

Copyright (c) 2013, Shinichiro Sato. All rights reserved.

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut
