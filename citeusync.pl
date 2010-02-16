#!/usr/bin/perl

use WWW::Mechanize;

my $home = $ENV{HOME} || (getpwuid($<))[7];

open(my $config_file, '<', "$home/.citeusync") or die $!;

@data = <$config_file>;
chomp @data;
$username = $data[0];
$password = $data[1];
$save_folder = $data[2];

my $mech = WWW::Mechanize->new();
$mech->get("http://www.citeulike.org/login");
print "Logging in...";
$mech->submit_form(
    form_name => 'frm',
    fields    => { username => $username, password => $password },
);
if ( $mech->success() ) {
    print "OK.\n";
}
else {
    print "Error.\n";
}
$mech->get("http://www.citeulike.org/user/$username");

my $content = $mech->content();

while ( $content =~ /\?page=([0-9]+)\">[0-9]/g ) {
    $last_page = $1;
}

$content = "";
for ( $i = 1 ; $i <= $last_page ; $i++ ) {
    $mech->get("http://www.citeulike.org/user/$username?page=$i");
    $content = $content . $mech->content();
}

my @links;
while ( $content =~ /item-pdf \{link: \'(\/pdf\/user\/$username\/article\/[^\']*)'/g ) {
    push( @links, "http://www.citeulike.org$1" );
}
print "Found $#links PDFs.\n";

my $files = join( "", glob("$save_folder/*.pdf") );

foreach $link (@links) {
    $link =~ /\/article\/([0-9]*)\//;
    my $article_id = $1;
    if ( $files =~ /$article_id/ ) {
        print("Already have $article_id.pdf.\n");
    }
    else {
        $files = $files . $article_id . ".pdf";
        print("Fetching $link...");
        $mech->get($link);
        if ( $mech->success() ) {
            print "OK.\n";
        }
        else {
            print "Error.\n";
        }
        $mech->save_content("$save_folder/$article_id.pdf");
    }
}

$mech->get("http://www.citeulike.org/bibtex/user/$username");
$content = $mech->content();
my @bibs = split( "\n@", $content );
foreach $bib (@bibs) {
    $bib =~ /citeulike-article-id\s+=\s+\{([0-9]*)\}/i;
    my $article_id = $1;
    if ( $files =~ /$article_id/ ) {
        my $url = "file://localhost$save_folder/$article_id.pdf";
        if ( $bib =~ /local-url/i ) {
            $bib =~ s/local-url.*}/Local-Url = {$url}/ig;
        }
        else {
            $bib =~ s/}\s+$/,\n Local-Url = {$url}}/g;
        }
    }
}

open( FILE, "> $save_folder/$username.bib" );
print FILE join( "\n@", @bibs );
close(FILE);

