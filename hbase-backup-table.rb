#!/usr/bin/env hbase-jruby

require 'date'
require 'java'
require 'optparse'

import org.apache.hadoop.fs.FileSystem
import org.apache.hadoop.fs.Path
import org.apache.hadoop.hbase.HBaseConfiguration
import org.apache.hadoop.hbase.client.HBaseAdmin

log_level = org.apache.log4j.Level::WARN
org.apache.log4j.Logger.getLogger("org.apache.zookeeper").setLevel(log_level)
org.apache.log4j.Logger.getLogger("org.apache.hadoop.hbase").setLevel(log_level)

class Backup
  attr_reader :db_table, :script, :config, :admin

  def initialize(options)
    @db_table = options[:db_table]
    @script = options[:script]

    @config = HBaseConfiguration.create
    @config.set("hbase.zookeeper.quorum", options[:zk])
    @config.set_int("hbase.zookeeper.property.clientPort", options[:zk_port])
    @config.set("zookeeper.znode.parent", options[:zk_root])

    @admin = HBaseAdmin.new(@config)
  end

  def backup
    name = "#{@db_table}-#{DateTime::now.strftime("%Y%m%dT%H%M%S")}"
    base = "/tmp/hbase-backup-table/"
    temp = "#{base}/#{name}"

    begin
      if @admin.list_snapshots.any? {|ss| ss.name == name } then
        raise "Snapshot #{name} already exists"
      end

      $stderr.puts "Creating snapshot #{name} from HBase table #{@db_table}"
      @admin.snapshot(name, @db_table);
    rescue => ex
      $stderr.puts "Failed to create snapshot: #{ex}"
      return
    end

    begin
      $stderr.puts "Exporting snapshot #{name} to HDFS directory #{temp}"
      if !system("hbase org.apache.hadoop.hbase.snapshot.ExportSnapshot -snapshot #{name} -copy-to #{temp} -mappers 16")
        fail "Failed to copy snapshot #{name} to #{temp}"
      end

      cmd = @script + [base, name]

      $stderr.puts "Invoking backup command #{cmd.join ' '}"
      if !system(*cmd)
        fail "#{cmd.join ' '} failed with rc #{$?}"
      end

      $stderr.puts "Backup finished!"

    rescue => ex
      $stderr.puts "Backup failed: #{ex}"
      return
    ensure
      begin
        $stderr.puts "Deleting snapshot #{name}"
        @admin.delete_snapshot(name)
      rescue => ex
        $stderr.puts ex
      end

      begin
        $stderr.puts "Removing #{temp} (and possibly #{base})"
        fs = FileSystem.get(@config);
        fs.delete(Path.new(temp), true)
        fs.delete(Path.new(base), false) rescue nil
      rescue => ex
        $stderr.puts ex
      end
    end
  end
end

if __FILE__ == $0
  opts = {
    :zk => "localhost",
    :zk_port => 2181,
    :zk_root => "/hbase"
  }

  op = OptionParser.new do |o|
    o.banner = "Usage #{$PROGRAM_NAME} [options] <backup-cmd> [<backup-cmd-args...>]"

    o.on("--db-table=TABLE", "HBase table name") do |arg|
      opts[:db_table] = arg;
    end

    o.on("--zk=HOSTS", "Connect to a HBase cluster via this ZooKeeper server. Default is <localhost>.") do |arg|
      opts[:zk] = arg
    end

    o.on("--zk-port=PORT", "Connect to a HBase cluster on this ZooKeeper port. Default is <2181>.") do |arg|
      opts[:zk_port] = arg.to_i
    end

    o.on("--zk-root=NODE", "Use this ZooKeeper root node. Default is </hbase>.") do |arg|
      opts[:zk_root] = arg
    end
  end

  op.parse!
  opts[:script] = ARGV

  if !opts[:db_table] || opts[:script].empty?
    $stderr.puts op
    exit 10
  end

  tb = Backup.new(opts)
  tb.backup
end
