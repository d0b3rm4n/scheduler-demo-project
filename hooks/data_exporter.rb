#!/bin/env ruby

exit 0

require '../../config/environment.rb'

require 'rest-client'
require 'json'

SERVER_URL = "http://data-warehouse/"


def upload(file_name)
	puts JSON.parse(RestClient::Request.new(method: :post, url: SERVER_URL + 'processors/nightly-2/process', payload: {multipart: true, file: File.new(file_name)}).execute.body)
end

def export_data(execution_id, path)
	origin_property_id = Property.find_by(name: "eventtype").id
	nightly_value_id = Value.find_by(value: 'nightly', property_id: origin_property_id).id

	execution = Execution.where("id = ?", execution_id).includes(execution_values: [], tasks: {task_values: [:value]}).select { |execution|
		execution.execution_values.find { |execution_value| execution_value.value_id == nightly_value_id }
        }[0]

	if not execution
		puts "Nothing to do, #{execution_id} is not a nightly!"
		exit
	end

	data = {
		id: execution_id,
		created_at: execution.created_at,
		tags: execution.execution_values.map { |execution_value| [execution_value.value.property.name, execution_value.value.value] },
		tasks: execution.tasks.map { |task| 
			{
				id: task.id,
				created_at: task.created_at,
				status: task.status.status,
				tags: task.task_values.map { |task_value| [task_value.value.property.name, task_value.value.value] },
				archives: task.description["archives"]
			}
		}
	}

	File.open('data.json', 'w') {|f| f.write(JSON.dump(data)) }
	puts `tar cvjf data.tar.bz2 data.json`
	upload("data.tar.bz2")
end


###################################################
## MAIN
####################################################
execution_id = ARGV[0]
status = ARGV[1]

if status == "finished"
	Dir.mktmpdir("data-exporter-hook-") {|tmpdir|
		puts "#{execution_id} - #{status} - #{tmpdir}"
		Dir.chdir(tmpdir){ |path|
			export_data(execution_id, path)
		}
	}
end

