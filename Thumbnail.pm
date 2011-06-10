package Image::Thumbnail;

use Imager;
use Apache2::ServerRec ();
use Apache2::RequestRec ();
use Apache2::RequestIO ();
use Apache2::RequestUtil ();
use Apache2::Response ();
use Apache2::Const -compile => qw(OK);
use APR::Table ();
use File::stat;
use File::Path qw(make_path);
use Date::Format;

sub handler {
    my $r = shift;
	
	$uri = $r->uri();
	
	my $cacheTime = ($r->dir_config('CacheTime') eq '')?15552000:$r->dir_config('CacheTime');
	$r->log_error($cacheTime);
	my ($width, $filename, $ext) = ($uri =~ m/thumbnail\/([0-9]{2,3})\/images\/(.*)\.(jpg|gif|png)/);	
	
	if ($ext) {
		my $format = ($ext eq "jpg")?"jpeg":$ext;
		
		$file = $r->document_root()."/images/$filename.$ext";

		$subpath = undef;
		if(index($filename,"/")>-1) {
			($subpath,$filename) = ($filename =~ m/([^\/]*)\/(.*)/);
		}

		$thumbpath = $r->document_root()."/thumbnail/".(($subpath eq '')?'':$subpath."/")."$width";
		$thumbfile = $thumbpath."/".$filename."_" . "$width.$ext";

		$r->log_error("Creating $thumbfile at $width in $format from $file");
		if (-e $file) {
			my $im = Imager->new(file=>$file, type=>$format) or die Imager->errstr();
			my $scale = ($width/$im->getwidth());

			if ($scale != 1)  {
				my $origmod = stat($file)->mtime;
				my $thumbmod = (-e $thumbfile)?stat($thumbfile)->mtime:0;

				if ((!(-e $thumbfile)) || ($thumbmod < $origmod)) {
					$r->log_error("create new thumb");

					make_path($thumbpath);

					my $thumb = $im->scale(scalefactor=>$scale);
					if ($Imager::formats{$format}) {
						$thumb->write(file=>$thumbfile) or die $thumb->errstr;
					}
				} else {
					$r->log_error("Using current thumbnail.");
				}
				$r->content_type("image/$format");
				$r->set_content_length(-s $thumbfile);
				if($cacheTime > 0) {
					$r->headers_out->add("Expires"=>time2str('%a, %d %h %Y %T GMT',($thumbmod+($cacheTime))));
					$r->headers_out->add("Last-Modified"=>time2str('%a, %d %h %Y %T GMT',($thumbmod+($cacheTime))));
					$r->headers_out->add('Cache-Control', "max-age=" . $cacheTime);
				}
				$r->sendfile($thumbfile);
			} else {
				$r->content_type("image/$format");
				$r->set_content_length(-s $file);
				$r->sendfile($file);
			}
			return Apache2::Const::OK;
		} 
	} 
	
	#If we got here something above failed, causing
	#nothing to return.
	$html = <<HTML;
<!DOCTYPE HTML PUBLIC "-//IETF//DTD HTML 2.0//EN">
<html><head>
<title>404 Not Found</title>
</head><body>
<h1>Not Found</h1>
<p>The requested URL was not found on this server.</p>
</body></html>
HTML
	$r->content_type("text/html");
	$r->print($html);
	$r->status(404);
	return Apache2::Const::NOT_FOUND;
}

1;