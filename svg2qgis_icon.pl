#!/usr/bin/perl

my $DESCRIPTION = 'Optimizes SVG format images for use as QGIS mapping icons.';
my $LICENSE = 'Kārlis Kalviškis, GPLv3';
my $VERSION = '0.0.13 2025/06/13';

# SVG description:
# https://developer.mozilla.org/en-US/docs/Web/SVG/Reference/

# Current limitations:
# Only 'path' elements has full transformation support.


use strict;
use warnings;
use utf8;
use open qw( :std :encoding(UTF-8) );
use XML::Twig;
use File::Basename;
use File::Path qw( make_path );
use Getopt::Long;
use Math::Trig;

my $WidthHeight = 64;


GetOptions('ind=s' => \my $In_DIR,
	'outd=s' => \my $Out_DIR,
	'size=i' => \$WidthHeight
);

if (!($In_DIR and  $Out_DIR)){
	print
"$DESCRIPTION ($VERSION)
Missing parameters!
Usage: $0 --ind DIR1 --outd DIR2 [--size NN]
	where:
	DIR1 – input directory
	DIR2 – output directory
	NN   – icon size (optional), default = 64,
	       use -1 to disable resize.
\n";
	exit 2;
}

make_path("$Out_DIR");

my @files = glob("$In_DIR/*.svg");
foreach my $file (@files){
	print basename($file), "\n";

	# Read the SVG file using XML::Twig.
	# pretty_print => 'indented', 'nice', 'indented_a'
	my $svg = XML::Twig->new(
		pretty_print => 'indented_a'
	);
	$svg->parsefile($file);

	# If all images should be the same size.
	my @scale;
	if ($WidthHeight > 0) {
		my $imageinfo = $svg->root;
		my $width = $imageinfo->att('width');
		$width =~ /([cimnptx]+)/;                #cm, in, mm, pc, pt, px
		my $unit = $1||'';
		$width =~ s/[^\d\.]//g;
		my $height = $imageinfo->att('height');
		$height =~ s/[^\d\.]//g;
		
		# 'cm' are 10 times bigger.
		if ($unit eq 'cm') {
			$width = $width * 10;
			$height = $height*10;
		}
		my $scale_xy;
		my $x_ratio = $WidthHeight / $width;
		my $y_ratio = $WidthHeight / $height;
		if ($x_ratio == 1 && $y_ratio < 1) {
			$scale_xy = $y_ratio;
		}
		elsif ($y_ratio == 1 && $x_ratio < 1) {
			$scale_xy = $x_ratio;
		}
		elsif ($x_ratio > 1 && $y_ratio >= $x_ratio) {
			$scale_xy = $x_ratio;
		}
		elsif ($y_ratio > 1 && $y_ratio <= $x_ratio) {
			$scale_xy = $y_ratio;
		}
		elsif ($x_ratio < 1 && $y_ratio <= $x_ratio) {
			$scale_xy = $y_ratio;
		}
		elsif ($y_ratio < 1 && $y_ratio >= $x_ratio) {
			$scale_xy = $x_ratio;
		}
		if ($scale_xy) {
			$imageinfo->set_att('width', $WidthHeight);
			$imageinfo->set_att('height', $WidthHeight);
			$imageinfo->del_att('viewBox');
			@scale = ($scale_xy,0,0,$scale_xy,0,0);
		}
		$imageinfo->set_att('width', $WidthHeight);
		$imageinfo->set_att('height', $WidthHeight);
	}
	
	# Delete «Inkscape» configuration information.
	$_ -> delete for $svg -> get_xpath('//sodipodi:namedview');

	# Process all elements.
	foreach my $node ($svg->root->children) {
		if (@scale) {
			&process_element($node, \@scale);
		}
		else {
			&process_element($node);
		}
	}
	
	# Create the new SVG file.
	my $svg_file = "$Out_DIR/" . basename($file);
	open my $FILE_OUT, '>', $svg_file or die "Cannot write to '$svg_file': $!";
	$svg->print($FILE_OUT);
	close $FILE_OUT;
}



print "\nDone!\n\n";

########################################################################

# Function to process each element
### Missing features:
### There could be several „transform” functions at the same time!
sub process_element {
	my ($element, $trans) = @_;
	my $transform;
	my @matrix = ();

	# If the element has a 'transform' attribute, handle it
	if ($transform = $element->att('transform')) {

		# Process the 'matrix' transform
		if ($transform =~ /matrix\(([^,\s]+)[,\s]+([^\s,]+)[,\s]+([^\s,]+)[,\s]+([^\s,]+)[,\s]+([^\s,]+)[,\s]+([^\s,]+)\)/) {
			@matrix = ($1, $2, $3, $4, $5, $6);
		}
		elsif ($transform =~ /translate\(([^,\s]+)[,\s]*([^\s,]*)\)/) {
			@matrix = (1, 0, 0, 1, $1, ($2 || 0));
		}
		elsif ($transform =~ /scale\(([^,\s]+)[,\s]*([^\s,]*)\)/) {
			@matrix = ($1, 0, 0, ($2 || $1), 0, 0);
		}
		elsif ($transform =~ /rotate\(([^,\s]+)[,\s]*([^\s,]*)[,\s]*([^\s,]*)\)/) {
			my $rad = deg2rad($1);
			my $cx =$2 || 0;
			my $cy = $3 || 0;
			my $cos = cos($rad);
			my $sin = sin($rad);
			if ($cx != 0 or $cy != 0) {
				@matrix = ($cos, $sin, -$sin, $cos,
					$cx - $cx * $cos + $cy * $sin,
					$cy - $cx * $sin - $cy * $cos
				);
			}
			else {
				@matrix = ($cos, $sin, -$sin, $cos, 0, 0);
			}
		}
		elsif ($transform =~ /skew(\w)\(([^,\s]+)\)/) {
			 my $rad = tan(deg2rad($2));
			 my ($b, $c);
			 if (uc $1 eq 'X'){
				 $b = 0;
				 $c = $rad;
			 }
			 else{
				 $b = $rad;
				 $c = 0;
			 }
			 @matrix = (1, $b, $c, 1, 0, 0);
		 }
	}
	if ($trans && @matrix) {
		@matrix = @{ multiply_matrices($trans, \@matrix) };
	}
	elsif ($trans) {
		@matrix = @$trans;
	}

	# Handle different types of elements
	if (@matrix) {
		
		# Grouped elemts.
		if  ($element->tag eq 'g'){
			foreach my $node2 ($element->children) {
				process_element($node2, \@matrix);
			}
		}
		elsif ($element->tag eq 'rect' || $element->tag eq 'image') {
			&handle_rect($element, \@matrix);
		}
		elsif ($element->tag eq 'circle') {
			&handle_circle($element, \@matrix);
		}
		elsif ($element->tag eq 'ellipse') {
			&handle_ellipse($element, \@matrix);
		}
		elsif ($element->tag eq 'polygon' || $element->tag eq 'polyline') {
			&handle_polygon($element, \@matrix);
		}
		elsif ($element->tag eq 'line') {
			&handle_line($element, \@matrix);
		}
		elsif ($element->tag eq 'path') {
			&handle_path($element, \@matrix);
		}

		# Remove the transform attribute from the element
		$element->del_att('transform');
	}
	elsif  ($element->tag eq 'rect' || $element->tag eq 'circle' || 
		$element->tag eq 'ellipse' || $element->tag eq 'line' ||
		$element->tag eq 'polygon' || $element->tag eq 'polyline' ||
		$element->tag eq 'path') {
		&process_colours($element);
	}
}

# Function to handle rect  elements
# Does not work for 'rotate', 'skewx', 'skewy' transformations.
# Missing feature:
# 	Should be converted to 'Path' otherwise these transformations
# 	cannot be removed.
sub handle_rect {
	my ($element, $matrix) = @_;
	my $x = $element->att('x') || 0;
	my $y = $element->att('y') || 0;
	my $width = $element->att('width') || 0;
	my $height = $element->att('height') || 0;
	my $rx = $element->att('rx') || 0;
	my $ry = $element->att('ry') || 0;

	# Apply the matrix transformation to the coordinates
	my ($new_x, $new_y) = &transform_point ($x, $y, $matrix);
	my $new_width = &new_radius ($width,  $matrix);
	my $new_height = &new_radius ($height,  $matrix);
	my $new_rx = &new_radius ($rx,  $matrix);
	my $new_ry = &new_radius ($ry,  $matrix);

	# Update the element coordinates
	$element->set_att('x', $new_x);
	$element->set_att('y', $new_y);
	$element->set_att('width', $new_width);
	$element->set_att('height', $new_height);
	$element->set_att('rx', $new_rx);
	$element->set_att('ry', $new_ry);
	$element->del_att('pathLength');

	&process_colours($element);
}

# Function to handle circle elements
# Does not work for 'non-uniform scale', 'skewx', 'skewy' transformations.
sub handle_circle {
	my ($element, $matrix) = @_;
	my $cx = $element->att('cx') || 0;
	my $cy = $element->att('cy') || 0;
	my $r = $element->att('r') || 0;

	# Apply the matrix transformation to the center coordinates
	my ($new_cx, $new_cy) = &transform_point ($cx, $cy, $matrix);
	my $new_r = &new_radius ($r,  $matrix);

	# Update the element center coordinates
	$element->set_att('cx', $new_cx);
	$element->set_att('cy', $new_cy);
	$element->set_att('r', $new_r);
	
	&process_colours($element);
}


# Function to handle ellipse elements
# Does not work for 'rotate', 'skewx', 'skewy' transformations.
sub handle_ellipse {
	my ($element, $matrix) = @_;
	my $cx = $element->att('cx') || 0;
	my $cy = $element->att('cy') || 0;
	my $rx = $element->att('rx') || 0;
	my $ry = $element->att('ry') || 0;

	# Apply the matrix transformation to the center coordinates
	my ($new_cx, $new_cy) = &transform_point ($cx, $cy, $matrix);
	my $new_rx = &new_radius ($rx,  $matrix);
	my $new_ry = &new_radius ($ry,  $matrix);

	# Update the element center coordinates
	$element->set_att('cx', $new_cx);
	$element->set_att('cy', $new_cy);
	$element->set_att('rx', $new_rx);
	$element->set_att('ry', $new_ry);

	&process_colours($element);
}

# Function to handle polygon, and polyline elements
sub handle_polygon {
	my ($element, $matrix) = @_;
	my ($a, $b, $c, $d, $e, $f) = @$matrix;
	my $points = $element->att('points');
	$points =~ s/([^Ee\s])-/$1 -/g;
	$points =~ s/^\s+|\s+$//g;
	my @points = split /[\s,]+/, $points;

	# Apply the matrix transformation to each point pair
	for (my $i = 0; $i < @points; $i += 2) {
		my $x = $points[$i];
		my $y = $points[$i+1];

		# Apply the matrix transformation
		my $new_x = $a * $x + $c * $y + $e;
		my $new_y = $b * $x + $d * $y + $f;

		$points[$i] = $new_x;
		$points[$i+1] = $new_y;
	}

	# Update the points attribute with the transformed values
	$element->set_att('points', join(' ', @points));

	&process_colours($element);
}

# Function to handle line.
sub handle_line {
	my ($element, $matrix) = @_;
	my $x1 = $element->att('x1');
	my $x2 = $element->att('x2');
	my $y1 = $element->att('y1');
	my $y2 = $element->att('y2');
	my ($new_x1, $new_y1) = &transform_point($x1, $y1, $matrix);
	my ($new_x2, $new_y2) = &transform_point($x2, $y2, $matrix);

	# Update the points attribute with the transformed values
	$element->set_att('x1', $new_x1);
	$element->set_att('y1', $new_y1);
	$element->set_att('x2', $new_x2);
	$element->set_att('y2', $new_y2);

	&process_colours($element);
}


# Function to handle path elements.
# Reference: https://developer.mozilla.org/en-US/docs/Web/SVG/Reference/Attribute/d
sub handle_path {
	my ($element, $matrix) = @_;
	return $element unless $element;
	my $path_d = $element->att('d');

	my @new_commands;
	my @commands = split(/([AaCcHhLlMmQqSsTtVvZz])/, $path_d);

	# current_ – coordinates of the current point using the new coordinate system.
	# current_old_ – coordinates of the current point using the original coordinate system.
	my ($current_x, $current_y, $current_old_x, $current_old_y) = (0, 0, 0, 0);

	for (my $i = 0; $i < @commands; $i++) {
		my $cmd = $commands[$i];
		if ($cmd =~ /[AaCcHhLlMmQqSsTtVv]/) {
			my $next = $commands[$i + 1];
			$next =~ s/([^Ee\s])-/$1 -/g;
			$next =~ s/^\s+|\s+$//g;
			my @coords = split(/[\s,]+/, $next);
			my @transformed_coords;
			

			# Handle control points and end points.
			# Absolute coordinates.
			# C – Draw a cubic Bézier curve.
			# L – Draw a line from the current point to the end point. 
			# M – Move the current point to the coordinate x,y.
			# Q – Draw a quadratic Bézier curve.
			# S – Draw a smooth cubic Bézier curve.
			# T – Draw a smooth quadratic Bézier curve.
			if ($cmd =~ /[MLCSQT]/) {
				for (my $j = 0; $j < @coords; $j += 2) {
					my ($new_x, $new_y) = &transform_point($coords[$j], $coords[$j + 1], $matrix);
					push @transformed_coords, ($new_x, $new_y);
					($current_x, $current_y) = ($new_x, $new_y);
					($current_old_x, $current_old_y) = ($coords[$j], $coords[$j + 1]);
				}
			}

			# H – Draw a horizontal line.
			# V - Draw a vertical line.
			elsif ($cmd =~ /[HV]/) {
				for (my $j = 0; $j < @coords; $j++) {
					my ($new_x, $new_y);
					if ($cmd =~ /[H]/) {
						($new_x, $new_y) = &transform_point($coords[$j], $current_old_y, $matrix);
						$current_old_x = $coords[$j];
					}
					else {
						($new_x, $new_y) = &transform_point($current_old_x, $coords[$j], $matrix);
						$current_old_y = $coords[$j];
					}
					push @transformed_coords, ($new_x, $new_y);
					($current_x, $current_y) = ($new_x, $new_y);
				}
				$cmd = 'L';
			}

			# Handle control points and end points.
			# Relative point movements.

			# l – Draw a line from the current point to the end point.
			#	( x, y)+
			# m – Move the current point by shifting the last known position
			#	of the path by dx along the x-axis and by dy along the y-axis.
			#	( x, y)+ 
			# t – Draw a smooth quadratic Bézier curve.
			#	( x, y)+
			#	1. From the current point.
			#	2. To the end point specified by x, y.
			#	3. The control point is the reflection of the control
			#		point of the previous curve command. If the previous
			#		command wasn't a quadratic Bézier curve, the control
			#		point is the same as the curve starting point.
			elsif ($cmd =~ /[lmt]/) {
				for (my $j = 0; $j < @coords; $j += 2) {
					my ($delta_x, $delta_y);
					($current_old_x, $current_old_y,
						$delta_x, $delta_y,
						$current_x, $current_y)  =
							&new_delta ($current_old_x, $current_old_y,
								$coords[$j], $coords[$j + 1],
								$current_x, $current_y,
								$matrix);
					push @transformed_coords, ($delta_x, $delta_y);
				}
			}

			# q – Draw a quadratic Bézier curve.
			#	( x1, y1, x, y)+
			#	1. From the current point.
			#	2. To the end point specified by x, y.
			#	3. The control point is specified by x1, y1.
			# s – Draw a smooth cubic Bézier curve.
			#	( x2, y2, x, y)+ 
			#	1. From the current point.
			#	2. To the end point specified by x, y.
			#	3. The end control point is specified by x2, y2.
			elsif ($cmd =~ /[qs]/) {
				for (my $j = 0; $j < @coords; $j += 4) {
					my ($delta_xc, $delta_yc, $delta_x, $delta_y);
					($delta_xc, $delta_yc)  =
							&new_delta_c ($current_old_x, $current_old_y,
								$coords[$j], $coords[$j + 1],
								$current_x, $current_y,
								$matrix);
					($current_old_x, $current_old_y,
						$delta_x, $delta_y,
						$current_x, $current_y)  =
							&new_delta ($current_old_x, $current_old_y,
								$coords[$j + 2], $coords[$j + 3],
								$current_x, $current_y,
								$matrix);
					push @transformed_coords, ($delta_xc, $delta_yc, $delta_x, $delta_y);
				}
			}


			# c - Draw a cubic Bézier curve.
			#	( x1, y1, x2, y2, x, y)+
			#	Smooth curve definitions using four points:
			#	1. sarting point (current point);
			#	2. to the  end point specified by x, y;
			#	3. the start control point is specified by x1, y1;
			#	4. the end control point is specified by x2, y2.
			elsif ($cmd =~ /[c]/) {
				for (my $j = 0; $j < @coords; $j += 6) {
					my ($delta_xc1, $delta_yc1, $delta_xc2, $delta_yc2, $delta_x, $delta_y);
					($delta_xc1, $delta_yc1)  =
							&new_delta_c ($current_old_x, $current_old_y,
								$coords[$j], $coords[$j + 1],
								$current_x, $current_y,
								$matrix);
					($delta_xc2, $delta_yc2)  =
							&new_delta_c ($current_old_x, $current_old_y,
								$coords[$j + 2], $coords[$j + 3],
								$current_x, $current_y,
								$matrix);
					($current_old_x, $current_old_y,
						$delta_x, $delta_y,
						$current_x, $current_y)  =
							&new_delta ($current_old_x, $current_old_y,
								$coords[$j + 4], $coords[$j + 5],
								$current_x, $current_y,
								$matrix);
					push @transformed_coords, ($delta_xc1, $delta_yc1, $delta_xc2, $delta_yc2, $delta_x, $delta_y);
				}
			}

			# h – Draw a horizontal line
			#	(dx+ )
			#	From the current point to the end point.
			# v – Draw a vertical line.
			#	( dy+ )
			#	From the current point to the end point.
			elsif ($cmd =~ /[hv]/) {
				for (my $j = 0; $j < @coords; $j++) {
					my ($delta_x, $delta_y);
					if ($cmd =~ /[h]/) {
						$delta_x = $coords[$j];
						$delta_y = 0;
					}
					else{
						$delta_x = 0;
						$delta_y = $coords[$j];
					}
					($current_old_x, $current_old_y,
						$delta_x, $delta_y,
						$current_x, $current_y)  =
							&new_delta ($current_old_x, $current_old_y,
								$delta_x, $delta_y,
								$current_x, $current_y,
								$matrix);
					push @transformed_coords, ($delta_x, $delta_y);
				}
				$cmd = 'l';
			}

			# Handle elliptical arc curve.
			# ( rx ry angle large-arc-flag sweep-flag x y)+ 
			# Draw an Arc curve from the current point to a point for which coordinates:
			# 1) [for 'A'] are x, y;
			# 2) [for 'a'] are those of the current point shifted by dx along
			#    the x-axis and dy along the y-axis.
			# The center of the ellipse used to draw the arc is determined
			# automatically based on the other parameters of the command.
			elsif ($cmd =~ /[Aa]/) {
				for (my $j = 0; $j < @coords; $j += 7) {
					my ($new_x, $new_y);
					if ($cmd =~ /[A]/) {
						($new_x, $new_y) = &transform_point($coords[$j + 5], $coords[$j + 6], $matrix);
						($current_x, $current_y) = ($new_x, $new_y);
					}
					else {
						($current_old_x, $current_old_y, $new_x, $new_y,$current_x, $current_y) =
							&new_delta(
								$current_old_x, $current_old_y,
								$coords[$j + 5], $coords[$j + 6],
								$current_x, $current_y,
								$matrix)
					}
					my $new_rx = &new_radius($coords[$j], $matrix);
					my $new_ry = &new_radius($coords[$j + 1], $matrix);
					push @transformed_coords, ($new_rx, $new_ry,
						$coords[$j + 2], $coords[$j + 3], $coords[$j + 4],
						$new_x, $new_y);
				}
			}

			else {
				push @transformed_coords, @coords;
			}
			
			push @new_commands, " $cmd " . join(',', @transformed_coords);
			$i++;
		}
		else {
			push @new_commands, $cmd;
		}
	}
	$element->set_att('d', join(' ', @new_commands));
	&process_colours($element);
}


sub transform_point {
	my ($x, $y, $matrix) = @_;
	my ($a, $b, $c, $d, $e, $f) = @$matrix;
	my $new_x = $a * $x + $c * $y + $e;
	my $new_y = $b * $x + $d * $y + $f;
	return ($new_x, $new_y);
}


# Join two matrices.
sub multiply_matrices {
    my ($m1, $m2) = @_;
    my ($a1, $b1, $c1, $d1, $e1, $f1) = @$m1;
    my ($a2, $b2, $c2, $d2, $e2, $f2) = @$m2;

    return [
        $a1 * $a2 + $c1 * $b2,
        $b1 * $a2 + $d1 * $b2,
        $a1 * $c2 + $c1 * $d2,
        $b1 * $c2 + $d1 * $d2,
        $a1 * $e2 + $c1 * $f2 + $e1,
        $b1 * $e2 + $d1 * $f2 + $f1
    ];
}

# Recalculate new deltas for a point.
# Returns:
# – old absolute coordinates;
# – new delta;
# – new absolute coordinates.
sub new_delta {
	my ($current_old_x, $current_old_y,  $old_delta_x, $old_delta_y, $current_x, $current_y, $matrix) = @_;
	$current_old_x = $current_old_x +  $old_delta_x;
	$current_old_y = $current_old_y + $old_delta_y;
	my($new_abs_x, $new_abs_y) = &transform_point($current_old_x, $current_old_y, $matrix);
	my($delta_x, $delta_y) = ($new_abs_x - $current_x, $new_abs_y - $current_y);
	return ($current_old_x, $current_old_y, $delta_x, $delta_y, $new_abs_x, $new_abs_y) ;
}

# Recalculate new deltas for a control point.
sub new_delta_c {
	my ($current_old_x, $current_old_y,  $old_delta_x, $old_delta_y, $current_x, $current_y, $matrix) = @_;
	$current_old_x = $current_old_x +  $old_delta_x;
	$current_old_y = $current_old_y + $old_delta_y;
	my($new_abs_x, $new_abs_y) = &transform_point($current_old_x, $current_old_y, $matrix);
	my($delta_x, $delta_y) = ($new_abs_x - $current_x, $new_abs_y - $current_y);
	return ($delta_x, $delta_y) ;
}
# Recalculte the new radius.
sub new_radius {
	my ($lenght, $matrix) = @_;
	my($new_start_x, $new_start_y) =  &transform_point(0, 0, $matrix);
	my($new_end_x, $new_end_y) = &transform_point(0, $lenght, $matrix);
	my $new_lenght = sqrt(($new_end_x - $new_start_x) ** 2 + ($new_end_y - $new_start_y) ** 2);
	return $new_lenght;
}

# Redefine colours to make compatible with «QGIS»
sub process_colours {
	my ($element) = @_;
	my ($style);
	if ($style = $element->att('style')) {

		# Filed element
		$element->del_att('style');
		
		# Dark colours are changed to black.
		if ($style =~/fill:#*\d+[^;]+;/){
			if ($style =~/stroke:none/){
				&filled_only($element);
			}
			else {
				&filled_element($element);
			}
		}
		elsif ($style =~/fill:none/){
			&line_only($element);
		}
		else {
			&outlined_element($element);
		}
	}
	elsif ($style = $element->att('fill')) {
		if ($style =~/#*\d+/){
			if (!$element->att('stroke')){
				&filled_only($element);
			}
			else{
				&filled_element($element);
			}
		}
		elsif ($style =~/none/){
			&line_only($element);
		}
		else {
			&outlined_element($element);
		}
	}
	else {
		&filled_element($element);
	}
}

sub filled_element {
	my ($element) = @_;
	$element->set_att(
		'fill'           => 'param(fill) #000000',
		'fill-opacity'   => 'param(fill-opacity)',
		'stroke'         => 'param(outline) #AAAAAA',
		'stroke-opacity' => 'param(outline-opacity)',
		'stroke-width'   => 'param(outline-width) 0.2'
		);
}

sub outlined_element {
	my ($element) = @_;
	$element->set_att(
		'fill'           => 'param(outline) #AAAAAA',
		'fill-opacity'   => 'param(outline-opacity)',
		'stroke'         => 'param(fill) #000000',
		'stroke-opacity' => 'param(fill-opacity)',
		'stroke-width'   => 'param(outline-width) 0.2'
		);
}

sub line_only {
	my ($element) = @_;
	$element->set_att(
		'fill'           => 'none',
		'stroke'         => 'param(fill) #000000',
		'stroke-opacity' => 'param(fill-opacity)',
		'stroke-width'   => 'param(outline-width) 0.2'
		);
}

sub filled_only {
	my ($element) = @_;
	$element->set_att(
		'fill'           => 'param(fill) #000000',
		'fill-opacity'   => 'param(fill-opacity)',
		'stroke'         => 'none'
		);
}
 
