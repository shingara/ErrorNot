require 'machinist/mongomapper'

Sham.composant { /\w+/.gen }
Sham.name { /\w+/.gen }
Sham.message { /[:paragraph:]/.gen }

MLogger.blueprint do
  project { Project.make }
  message
  resolved { false }
end

Project.blueprint do
  name
end
