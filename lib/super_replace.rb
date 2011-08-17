#!/usr/bin/env ruby

# TODO: this doesn't cope with the situation where a more than one component of the path needs to be renamed
# e.g.
#
# tests/cases/models/[discussion]s
# tests/cases/models/[discussion]s/[discussion].test.php
#
# because by the time it gets to the second, the parent has been renamed so path is invalid. running a second parse fixes it,
#
# Git throws this error in the scenario above when it gets to the second:
#   fatal: bad source, source=tests/cases/models/discussions/discussion.test.php, destination=tests/cases/models/conversations/conversation.test.php
#
# TODO: modularise this into separate components, e.g. scanner, replacer etc and unit test each part
# TODO: allow ignore configurations to be saved in a hidden .splace config file per base dir
# TODO: break this into at least two classes for the two modes, contents and paths and give them different options and banner
#

require 'optparse'

module SuperReplace

  class Base

    # These things should be settable by arguments

    EXTENSIONS_TO_REPLACE_INSIDE = %w[php ctp css js jst]

    RENAME_IGNORE_PATHS = %w[
      config/migrations/**/*
      plugins/**/*
      tmp/**/*
    ]

    REPLACE_INSIDE_IGNORE_PATHS = %w[
      config/migrations/**/*
      webroot/cache_css/**/*
      webroot/cache_js/**/*
      plugins/**/*
      tmp/**/*
    ]


    # Handy ansi escape colour codes, see here: http://ascii-table.com/ansi-escape-sequences.php

    INVERTSTART = "\e[7m"
    INVERTEND = "\e[0m"
    BOLDSTART = "\e[1m"
    BOLDEND = "\e[0m"

    def run

      @options = {
        :for_real => false,
        :from => nil,
        :to => nil,
        :type => nil
      }

      o = OptionParser.new do |opts|
        opts.banner = "Usage: splace [options] from to"
        opts.on("-f", "--for-real", "Run for real, no dry run.") do |r|
          @options[:for_real] = r
        end
        opts.on("-t TYPE", "--type TYPE", [:paths,:contents], "Type, 'paths' or 'contents'") do |t|
          @options[:type] = t
        end
      end
      o.parse!

      puts "Options:"
      puts @options.inspect

      if ARGV.count < 2
        puts o.help
        exit
      end

      @from = ARGV[0]
      @to = ARGV[1]

      puts "From: "+@from
      puts "To: "+@to

      if @options[:type] == :paths
        replace_paths
      elsif @options[:type] == :contents
        replace_contents
      else
        puts "No type specified."
        puts o.help
      end

    end

    def replace_paths
      puts "FILES TO RENAME"

      # this luckily seems to only match where the last component of path includes the word,
      # i.e. we don't want results like:
      # some/directory#{@from}/anything.php
      # because the directory will be renamed separately just like a file, eglg
      # some/directory#{@from}
      #
      # TODO: allow regex in @from ? means we can't use glob I assume, and instead manually filter all paths.

      files_to_rename = Dir.glob("**/*#{@from}*")

      RENAME_IGNORE_PATHS.each do |ignore_path|
        ignore = Dir.glob(ignore_path)
        files_to_rename -= ignore
      end

      files_to_rename.each do |before|

        before.gsub!(' ','\ ')
        before_highlighted = before.gsub(@from, BOLDSTART+@from+BOLDEND)

        after = before.gsub(@from, @to)
        after_highlighted = before.gsub(@from, BOLDSTART+@to+BOLDEND)

        # TODO: safer to use one string, and strip escape metacharacters before running, so we really see the true command:

        cmd = "git mv #{before} #{after}"
        cmd_highlighted = "git mv #{before_highlighted} #{after_highlighted}"
        puts cmd_highlighted

        if @options[:for_real]
          puts `#{cmd}`
        end
      end
      puts ""
    end

    def replace_contents
      puts "FILES TO SEARCH CONTENT"
      files_to_search = Dir.glob("**/*.{"+EXTENSIONS_TO_REPLACE_INSIDE.join(',')+"}")

      REPLACE_INSIDE_IGNORE_PATHS.each do |ignore_path|
        ignore = Dir.glob(ignore_path)
        files_to_search -= ignore
      end

      files_to_search.each do |filename|
        text = File.read(filename)

        # if the whole of the file contains the text at all, output the lines that contain it

        if text.match(@from)
          puts INVERTSTART + filename + INVERTEND
          File.open(filename, "r") do |file|
            linenum = 1;
            while (line = file.gets)
              if line.match(@from)
                find = Regexp.new("("+@from+")")
                #puts find.to_s
                replace = BOLDSTART+'\1'+BOLDEND
                puts '   ' + linenum.to_s + ': ' + line.gsub(find,replace)
              end
              linenum = linenum + 1
            end
          end
        end

        if @options[:for_real]
          text = text.gsub(@from,@to)
          File.open(filename, 'w') {|f| f.write(text) }
        end

      end
      puts ""
    end

  end

end

