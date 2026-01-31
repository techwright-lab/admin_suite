class DropLegacySignalsEmailPipelineTables < ActiveRecord::Migration[8.1]
  def change
    drop_table :signals_email_pipeline_events, if_exists: true
    drop_table :signals_email_pipeline_runs, if_exists: true
  end
end
