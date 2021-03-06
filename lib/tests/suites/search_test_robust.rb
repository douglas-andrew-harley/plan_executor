module Crucible
  module Tests
    class RobustSearchTest < BaseSuite

      def id
        'Search002'
      end

      def description
        'Deeper testing of search capabilities.'
      end

      def initialize(client1, client2=nil)
        super(client1, client2)
        @category = {id: 'core_functionality', title: 'Core Functionality'}
      end

      def setup
        # Create a patient with gender:missing
        patient = Crucible::Generator::Resources.new.minimal_patient
        patient.identifier = [FHIR::Identifier.new]
        patient.identifier[0].value = SecureRandom.urlsafe_base64

        ignore_client_exception { @patient = FHIR::Patient.create(patient) }

        assert @patient, "Response code #{@client.reply.code} on patient creation."

        # read all the patients
        @patients = FHIR::Patient.all()

        # create a condition matching the first patient
        condition = ResourceGenerator.generate(FHIR::Condition,1)

        # remove common constraint issues for conditions
        # these fields don't affect the test so no need to have them in the resource that we are using
        # but if they are technically malformed some servers will reject them, and cause us to skip the whole test
        condition.evidence = nil
        condition.stage = nil
        condition.abatementAge = nil
        condition.onsetAge = nil

        condition.subject = ResourceGenerator.generate(FHIR::Reference)

        condition.subject.id = @patients.entry.first.resource.id
        options = {
          :id => condition.subject.id,
          :resource => @patients.entry.first.resource.class
        }
        condition.subject.reference = @client.resource_url(options)

        ignore_client_exception { @condition = FHIR::Condition.create(condition) }

        assert @condition, "Response code #{@client.reply.code} on condition creation."

        # create some observations
        @observations = [4.12345, 4.12346, 4.12349, 5.12, 6.12].map {|n| create_observation(n)}
      end

      def create_observation(value)
        observation = FHIR::Observation.new
        observation.status = 'preliminary'
        code = FHIR::Coding.new
        code.system = 'http://loinc.org'
        code.code = '2164-2'
        observation.code = FHIR::CodeableConcept.new
        observation.code.coding = [ code ]
        observation.valueQuantity = FHIR::Quantity.new
        observation.valueQuantity.system = 'http://unitofmeasure.org'
        observation.valueQuantity.value = value
        observation.valueQuantity.unit = 'mmol'
        body = FHIR::Coding.new
        body.system = 'http://snomed.info/sct'
        body.code = '182756003'
        observation.bodySite = FHIR::CodeableConcept.new
        observation.bodySite.coding = [ body ]
        begin
          result = FHIR::Observation.create(observation) rescue nil
        rescue ClientException=>e
        end
        assert result, "Response code #{@client.reply.code} on observation creation."
        result
      end

      def teardown
        ignore_client_exception { @patient.destroy }
        ignore_client_exception { @condition.destroy }
        @observations.each {|o| ignore_client_exception { o.destroy } }
      end

    [true,false].each do |flag|  
      action = 'GET'
      action = 'POST' if flag

      test "SR01#{action[0]}","Patient Matching using an MPI (#{action})" do
        metadata {
          links "#{BASE_SPEC_LINK}/patient.html#match"
          validates resource: 'Patient', methods: ['search']
          validates extensions: ['extensions']
        }
        options = {
          :search => {
            :flag => flag,
            :compartment => nil,
            :parameters => {
              '_query' => 'mpi',
              'given' => @patient.name[0].given[0]
            }
          }
        }
        reply = @client.search(FHIR::Patient, options)
        assert_response_ok(reply)
        assert_bundle_response(reply)        
 
        has_mpi_data = true
        has_score = true
        reply.resource.entry.each do |entry|
          has_score = has_score && entry.try(:search).try(:score)
          entry_has_mpi_data = false
          if entry.search
            entry.search.extension.each do |e|
              if (e.url=='http://hl7.org/fhir/StructureDefinition/patient-mpi-match' && e.value && ['certain','probable','possible','certainly-not'].include?(e.valueCode))
                entry_has_mpi_data = true
              end
            end
          end
          has_mpi_data = has_mpi_data && entry_has_mpi_data
        end
        assert( has_score && has_mpi_data, "Every Patient Matching result requires a score and 'patient-mpi-match' extension.", reply.body)
      end

# Search Parameter Types    
#   Number
#   Date/DateTime
#   String
#   Token
#   Reference
#   Composite
#   Quantity
#   URI
# Parameters for all resources
#   _id
#   _lastUpdated
#   _tag
#   _profile
#   _security
#   _text
#   _content
#   _list
#   _query
# Search result parameters
#   _sort
#   _count
#   _include
#   _revinclude
#   _summary
#   _elements
#   _contained
#   _containedType
    end # EOF [true,false].each

    end
  end
end
