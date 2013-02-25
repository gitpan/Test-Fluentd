#!perl -w
use strict;
use Test::More;
use Test::Flatten;

use Test::Fluentd;

my $output_dir = "./tmp/";
mkdir $output_dir;
mkdir "log";
subtest 'test_from_file_fluent.conf'=> sub {
    my $input_file = $output_dir . 'input.txt';
    my $output_file = $output_dir . 'file_output.txt';
    my $tag = "tag.tag";
    
    opendir(my $dh , $output_dir) or die;
    my $already_exist_files = {map{$_ => 1}readdir($dh)};
    closedir ($dh);
    my $tf = Test::Fluentd->new(
        base_dir => './' ,
        input_txt =>  $input_file,
        fluent_log => 'log/fluent_log.txt' ,
        fluent_conf_file => 'etc/fluent.conf' ,
    );
    diag "wait for launch fluentd";
    $tf->run;

    for(1..10){
        print "TAG\t$_\n";
    }

    $tf->stop;
    diag "wait for stop fluentd";
    $tf->remove_input_txt;
    
    opendir(my $dh_after , $output_dir) or die;
    my $added_file;
    for(readdir($dh_after)){
        if($_=~ /^file_output/){
            $added_file = $_ unless $already_exist_files->{$_};
        }
    }
    closedir ($dh_after);
    open my $fh , '<' , $output_dir . $added_file or die 'cant open file !';
    warn "check output file for $added_file";
    while(<$fh>){
        ok $_ =~ /"log_tag":"TAG","value":"\d+"/;
    }
    close $fh;
    system "rm $output_dir/*";

    done_testing;
};

subtest 'test_from_string_fluent_config'=> sub {
    my $input_file = $output_dir . 'input.txt';
    my $output_file = $output_dir . 'string_output.txt';
    my $tag = "tag.tag";
    my $conf = <<'EOS';
<source>
  type tail
  path %s
  pos_file ./tmp/pos.pos
  tag %s
  format /^(?<log_tag>TAG)\t(?<value>\d+?)$/
</source>
<match %s>
  type file
  path %s
</match>
EOS
    
    opendir(my $dh , $output_dir) or die;
    my $already_exist_files = {map{$_ => 1}readdir($dh)};
    closedir ($dh);
    my $tf = Test::Fluentd->new(
        base_dir => './' ,
        input_txt =>  $input_file,
        fluent_log => 'log/fluent_log.txt' ,
        fluent_conf_file => 'tmp/fluent.conf' ,
        fluent_conf => sprintf($conf , $input_file , $tag , $tag , $output_file) ,
    );
    diag "wait for launch fluentd";
    $tf->run;
    for(1..10){
        print "TAG\t$_\n";
    }

    $tf->stop;
    diag "wait for stop fluentd";
    $tf->remove_input_txt;
    opendir(my $dh_after , $output_dir) or die;
    my $added_file;
    for(readdir($dh_after)){
        if($_=~ /^string_output/){
            $added_file = $_ unless $already_exist_files->{$_};
        }
    }
    closedir ($dh_after);
    open my $fh , '<' , $output_dir . $added_file or die 'cant open file !';
    warn "check output file for $added_file";
    while(<$fh>){
        ok $_ =~ /"log_tag":"TAG","value":"\d+"/;
    }
    close $fh;
    system "rm $output_dir/*";

    done_testing;
};

done_testing;
