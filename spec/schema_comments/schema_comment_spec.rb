# -*- coding: utf-8 -*-
require File.join(File.dirname(__FILE__), '../spec_helper')

describe SchemaComments::SchemaComment do

  IGNORED_TABLES = %w(schema_migrations)

  before(:each) do
    SchemaComments.yaml_path = File.expand_path(File.join(File.dirname(__FILE__), 'schema_comments.yml'))
    FileUtils.rm(SchemaComments.yaml_path, :verbose => true) if File.exist?(SchemaComments.yaml_path)
    
    (ActiveRecord::Base.connection.tables - IGNORED_TABLES).each do |t|
      ActiveRecord::Base.connection.drop_table(t) rescue nil
    end
    ActiveRecord::Base.connection.initialize_schema_migrations_table
    ActiveRecord::Base.connection.execute "DELETE FROM #{ActiveRecord::Migrator.schema_migrations_table_name}"
  end

  describe :yaml_access do
    before{@original_yaml_path = SchemaComments.yaml_path}
    after {SchemaComments.yaml_path = @original_yaml_path}

    # http://d.hatena.ne.jp/akm/20091213#c1271134505
    # プラグインの更新ご苦労さまです。
    # とても便利に使わせていただいてます。
    #
    # ところが本日更新してみたら0.1.3になっていて、
    # コメントの生成に失敗するようになってしまいました。
    #
    # 原因を探ってみましたところ、
    # コメントを一個も書いていないマイグレーションでは、
    # nilにHashKeyOrderableをextendしようとして落ちていました。
    #
    # プラグインによって自動で作られるマイグレーションがあるのですが、
    # 必ずしもコメントを書くとは限らないので、
    # コメントがないときは無視？もしくはそのままカラム名をいれるのがいいのかなと思いました。
    #
    # # schema_comment.rb:154-164　あたり
    #
    # よろしければ対応していただけたらと思います。
    it "dump without column comment" do
      migration_path = File.join(MIGRATIONS_ROOT, 'valid')
      Dir.glob('*.rb').each{|file| require(file) if /^\d+?_.*/ =~ file}

      ActiveRecord::Migrator.up(migration_path, 8)
      ActiveRecord::Migrator.current_version.should == 8

      SchemaComments.yaml_path = 
        File.expand_path(File.join(
          File.dirname(__FILE__), "schema_comments_users_without_column_hash.yml"))
      SchemaComments::SchemaComment.yaml_access do |db|
        db['column_comments']['products']['name'] = "商品名"
      end
    end
    {
      "table_comments" => lambda{|db| db['column_comments']['users']['login'] = "ログイン"},
      "column_comments" => lambda{|db| db['table_comments']['users'] = "物品"},
      "column_hash" => lambda{|db| db['column_comments']['users']['login'] = "ログイン"}
    }.each  do |broken_type, proc|
      it "raise SchemaComments::YamlError with broken #{broken_type}" do
        migration_path = File.join(MIGRATIONS_ROOT, 'valid')
        Dir.glob('*.rb').each{|file| require(file) if /^\d+?_.*/ =~ file}

        ActiveRecord::Migrator.up(migration_path, 8)
        ActiveRecord::Migrator.current_version.should == 8

        SchemaComments.yaml_path = 
          File.expand_path(File.join(
            File.dirname(__FILE__), "schema_comments_broken_#{broken_type}.yml"))
        lambda{
          SchemaComments::SchemaComment.yaml_access(&proc)
        }.should raise_error(SchemaComments::YamlError)
      end
    end
    
  end

end
