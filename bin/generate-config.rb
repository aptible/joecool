require 'json'

containers = JSON.parse(ENV.fetch('CONTAINERS'))
fields = JSON.parse(ENV.fetch('FIELDS'))

config = {
  'network' => {
    'servers' => [ENV.fetch('LOGSTASH_ENDPOINT')],
    'timeout' => Integer(ENV.fetch('LOGSTASH_TIMEOUT', 15)),
    'ssl ca' => 'logstash.crt',
    'dead time' => '720h'
  },
  'files' => [
    {
      'paths' => containers.map { |c| "/tmp/dockerlogs/#{c}*/*-json.log" },
      'fields' => fields
    },
    {
      'paths' => containers.map { |c| "/tmp/activitylogs/#{c}*-json.log" },
      'fields' => fields.merge('source' => 'aptible')
    }
  ]
}

puts JSON.pretty_generate(config)
