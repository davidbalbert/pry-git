# pry-git.rb
# (C) John Mair (banisterfiend); MIT license

require "pry-git/version"
require "pry"

module PryGit
  GitCommands = Pry::CommandSet.new do
    command "blame", "Show blame for a method", :requires_gem => "grit" do |meth_name|
      require 'grit'
      if (meth = get_method_object(meth_name, target, {})).nil?
        output.puts "Invalid method name: #{meth_name}."
        next
      end

      repo ||= Grit::Repo.new(Dir.pwd)
      start_line = meth.source_location.last
      num_lines = meth.source.lines.count
      authors = repo.blame(meth.source_location.first).lines.select do |v|
        v.lineno >= start_line && v.lineno <= start_line + num_lines
      end.map do |v|
        v.commit.author.output(Time.new).split(/</).first.strip
      end

      lines_with_blame = []
      meth.source.lines.zip(authors) { |line, author| lines_with_blame << ("#{author}".ljust(10) + colorize_code(line)) }
      output.puts        lines_with_blame.join
    end

    command "diff", "Show the diff for a method", :requires_gem => ["grit", "diffy"] do |meth_name|
      require 'grit'
      require 'diffy'

      if (meth = get_method_object(meth_name, target, {})).nil?
        output.puts "Invalid method name: #{meth_name}."
        next
      end

      output.puts colorize_code(Diffy::Diff.new(method_code_from_head(meth), meth.source))
    end

    helpers do
      def get_file_from_commit(path)
        repo = Grit::Repo.new(Dir.pwd)
        head = repo.commits.first
        tree_names = path.split("/")
        start_tree = head.tree
        blob_name = tree_names.last
        tree = tree_names[0..-2].inject(start_tree)  { |a, v|  a.trees.find { |tree| tree.basename == v } }
        blob = tree.blobs.find { |v| v.basename == blob_name }
        blob.data
      end

      def method_code_from_head(meth)
        rel_path = relative_path(meth.source_location.first)
        code = get_file_from_commit(rel_path)
        start_line = meth.source_location.last
        code_length = meth.source.lines.count
        code.lines.to_a[(start_line - 1)...((start_line -1) + code_length)].join
      end

      def relative_path(path)
        path =~ /#{Regexp.escape(File.expand_path(Dir.pwd))}\/(.*)/
        $1
      end
    end

  end
end

Pry.commands.import PryGit::GitCommands
