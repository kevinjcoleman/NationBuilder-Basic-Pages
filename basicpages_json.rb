require 'nationbuilder'
require 'csv'
require 'json'

nation_slug = 'organizerkevincoleman'
api_token = '4319835f09710397c8cd979aea0cc865e3168ea78b0fc874401325e01abbc108'
client = NationBuilder::Client.new(nation_slug, api_token, retries: 8)
result = client.call(:basic_pages, :index, site_slug: 'kevinjamescoleman')['results']

result.each do |w|
slug = w['slug']
    puts slug
end