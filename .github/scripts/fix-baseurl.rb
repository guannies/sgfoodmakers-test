#!/usr/bin/env ruby
# frozen_string_literal: true

# Prefix leftover root-relative URLs in the built site with the Pages baseurl.
#
# The Isomer remote theme is only half baseurl-aware. Page bodies in this repo
# all go through `relative_url`, and so do the theme's stylesheets, so those
# come out correct. But the theme emits several URL groups raw:
#
#   - nav links and the logo straight out of _data/navigation.yml
#   - footer links out of _data/footer.yml
#   - left-nav collection links and `page.url` breadcrumbs
#   - hardcoded masthead assets (/assets/img/lock.svg, ogp_logo.svg, ...)
#   - the homepage link href="/" and the search form action="/search/"
#
# On a project Pages site (served under /<repo>/) every one of those 404s. The
# theme is remote and not vendored here, so it can't be fixed at the source —
# this pass rewrites the built HTML instead. Content files stay baseurl-free,
# which keeps the production build for sgfoodmakers.sg unchanged.
#
# Only HTML is touched: the built CSS and JS carry no absolute path literals.
#
# Usage: fix-baseurl.rb <baseurl> [site_dir]
#        PAGES_BASEURL=/repo fix-baseurl.rb

require "find"

baseurl = (ARGV[0] || ENV["PAGES_BASEURL"]).to_s.strip.chomp("/")
site_dir = ARGV[1] || "_site"

abort "usage: fix-baseurl.rb <baseurl> [site_dir]" if baseurl.empty?
abort "fix-baseurl: #{site_dir} not found" unless Dir.exist?(site_dir)

# Attributes that can hold a root-relative URL in the theme's output.
ATTRS = %w[href src action poster formaction data-src].freeze

# Matches attr="/path" / attr='/path'. The (?!/) guards protocol-relative
# //cdn.example.com URLs, which are absolute and must not be rewritten.
PATTERN = /\b(#{ATTRS.join("|")})=(["'])\/(?!\/)([^"']*)\2/.freeze

scanned = 0
changed = 0
rewrites = 0

Find.find(site_dir) do |path|
  next unless File.file?(path) && File.extname(path) == ".html"

  scanned += 1
  html = File.read(path)

  fixed = html.gsub(PATTERN) do
    attr = Regexp.last_match(1)
    quote = Regexp.last_match(2)
    url = "/#{Regexp.last_match(3)}"

    # Already prefixed by `relative_url` during the build — leave it alone.
    if url == baseurl || url.start_with?("#{baseurl}/")
      "#{attr}=#{quote}#{url}#{quote}"
    else
      rewrites += 1
      "#{attr}=#{quote}#{baseurl}#{url}#{quote}"
    end
  end

  next if fixed == html

  File.write(path, fixed)
  changed += 1
end

puts "fix-baseurl: prefixed #{baseurl} on #{rewrites} URLs across " \
     "#{changed}/#{scanned} HTML files"
