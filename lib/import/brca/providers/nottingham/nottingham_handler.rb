require 'possibly'

module Import
  module Brca
    module Providers
      module Nottingham
        # Process Nottingham-specific record details into generalized internal genotype format
        class NottinghamHandler < Import::Brca::Core::ProviderHandler
          include ExtractionUtilities
          TEST_TYPE_MAP = { 'confirmation' => :diagnostic,
                            'diagnostic' => :diagnostic,
                            'predictive' => :predictive,
                            'family studies' => :predictive,
                            'indirect' => :predictive } .freeze

          TEST_SCOPE_MAP = { 'Hereditary Breast and Ovarian Cancer (BRCA1/BRCA2)' => :full_screen,
                             'BRCA1 + BRCA2 + PALB2'                              => :full_screen,
                             'Breast Cancer Core Panel'                           => :full_screen,
                             'Breast Cancer Full Panel'                           => :full_screen,
                             'Breast Core Panel'                                  => :full_screen,
                             'BRCA1/BRCA2 PST'                                    => :targeted_mutation,
                             'Cancer PST'                                         => :targeted_mutation
                            }.freeze
          
          TEST_STATUS_MAP = { '1: Clearly not pathogenic' => :negative,
                              '2: likely not pathogenic' => :negative,
                              '2: likely not pathogenic variant' => :negative,
                              'Class 2 Likely Neutral' => :negative,
                              'Class 2 likely neutral variant' => :negative,
                              '3: variant of unknown significance (VUS)' => :positive,
                              '4: likely pathogenic' => :positive,
                              '4:likely pathogenic' => :positive,
                              '4: Likely Pathogenic' => :positive,
                              '5: clearly pathogenic' => :positive
                            }.freeze


          TEST_SCOPE_TTYPE_MAP = { 'Diagnostic' => :full_screen,
                                   'Indirect'   => :full_screen,
                                   'Predictive' => :targeted_mutation
          }
          
          PASS_THROUGH_FIELDS = %w[age authoriseddate
                                   receiveddate
                                   specimentype
                                   providercode
                                   consultantcode
                                   servicereportidentifier] .freeze

          NEGATIVE_TEST = /Normal/i.freeze
          VARPATHCLASS_REGEX = /(?<varpathclass>[0-9](?=\:))/.freeze
          CDNA_REGEX = /c\.(?<cdna>[0-9]+[^\s|^, ]+)/i .freeze

          def initialize(batch)
            @failed_genotype_parse_counter = 0
            @genotype_counter = 0
            @ex = LocationExtractor.new
            super
          end

          def process_fields(record)
            @lines_processed += 1
            genotype = Import::Brca::Core::GenotypeBrca.new(record)
            genotype.add_passthrough_fields(record.mapped_fields,
                                            record.raw_fields,
                                            PASS_THROUGH_FIELDS)
            add_simple_fields(genotype, record)
            # add_complex_fields(genotype, record)
            assign_test_scope(record, genotype)
            process_gene(genotype, record) # Added by Francesco
            process_cdna_change(genotype, record)
            process_varpathclass(genotype, record)
            add_organisationcode_testresult(genotype)
            assign_test_status(record, genotype) # added by Francesco
            @persister.integrate_and_store(genotype)
          end

          def add_organisationcode_testresult(genotype)
            genotype.attribute_map['organisationcode_testresult'] = '698A0'
          end

          def add_simple_fields(genotype, record)
            testingtype = record.raw_fields['moleculartestingtype']
            genotype.add_molecular_testing_type_strict(TEST_TYPE_MAP[testingtype.downcase.strip])
            # variant_path_class = record.raw_fields['teststatus']
            # genotype.add_variant_class(variant_path_class.downcase) unless variant_path_class.nil?
            received_date = record.raw_fields['sample received in lab date']
            genotype.add_received_date(received_date.downcase) unless received_date.nil?
          end

          def assign_test_scope(record, genotype)
            testscopefield = record.raw_fields['disease']
            testtypefield = record.raw_fields['moleculartestingtype']
            if TEST_SCOPE_MAP[testscopefield].present?
              genotype.add_test_scope(TEST_SCOPE_MAP[testscopefield])
            elsif %w[PALB2 CDH1 TP53].include? testscopefield
               genotype.add_test_scope(TEST_SCOPE_TTYPE_MAP[testtypefield])
            end
          end

          def add_complex_fields(genotype, record)
            Maybe(record.raw_fields['disease']).each do |disease|
              case disease.downcase.strip
              when 'hereditary breast and ovarian cancer (brca1/brca2)'
                genotype.add_test_scope(:full_screen)
              when 'brca1/brca2 pst'
                genotype.add_test_scope(:targeted_mutation)
              end
            end
            # Maybe(record.raw_fields['genotype']).each do |geno|
            #   @genotype_counter += 1
            #   @failed_genotype_parse_counter += genotype.add_typed_location(@ex.extract_type(geno))
            # end
          end

          # def extract_teststatus(genotype, record)
          #   case record.raw_fields['teststatus'].to_s.downcase
          #   when /normal|completed/i
          #     genotype.add_status(:negative)
          #   else genotype.add_status(:positive)
          #   end
          # end

          def assign_test_status(record, genotype)
            teststatusfield = record.raw_fields['teststatus']
            variantfield = record.raw_fields['genotype']
            if TEST_STATUS_MAP[teststatusfield].present?
              genotype.add_status(TEST_STATUS_MAP[teststatusfield])
            elsif teststatusfield == 'Normal' && variantfield.nil?
              genotype.add_status(:negative)
            elsif teststatusfield == 'Completed' && variantfield.nil?
              genotype.add_status(:negative)
            elsif teststatusfield == 'Normal' && variantfield.scan(CDNA_REGEX).size.positive?
              genotype.add_status(:positive)
            elsif teststatusfield == 'Completed' && variantfield.scan(CDNA_REGEX).size.positive?
              genotype.add_status(:positive)
            # else binding.pry
            end
          end

          def process_cdna_change(genotype, record)
            case record.raw_fields['genotype']
            when CDNA_REGEX
              genotype.add_gene_location($LAST_MATCH_INFO[:cdna])
              @logger.debug "SUCCESSFUL cdna change parse for: #{$LAST_MATCH_INFO[:cdna]}"
            end
          end
    
          def process_varpathclass(genotype, record)
            case record.raw_fields['teststatus']
            when VARPATHCLASS_REGEX
              genotype.add_variant_class($LAST_MATCH_INFO[:varpathclass].to_i)
              @logger.debug "SUCCESSFUL variantpathclass parse for: #{$LAST_MATCH_INFO[:varpathclass]}"
            end
          end
          
          # def extract_variantclass_from_genotype(genotype, record)
          #   varpathclass_field = record.raw_fields['teststatus'].to_s.downcase
          #   case varpathclass_field
          #   when VARPATHCLASS_REGEX
          #     genotype.add_variant_class($LAST_MATCH_INFO[:varpathclass].to_i) unless varpathclass_field.nil?
          #     @logger.debug "SUCCESSFUL VARPATHCLASS parse for: #{$LAST_MATCH_INFO[:varpathclass]}"
          #   else
          #     @logger.debug "FAILED VARPATHCLASS parse for: #{record.raw_fields['teststatus']}"
          #   end
          # end

          def process_gene(genotype, record) # Added by Francesco
            gene = record.mapped_fields['gene'].to_i # Added by Francesco
            genotype.add_gene(gene) unless gene.nil? # Added by Francesco
          end


          def summarize
            @logger.info '***************** Handler Report ******************'
            @logger.info "Num failed genotype parses: #{@failed_genotype_parse_counter}"\
                         'of #{@genotype_counter}'
            @logger.info "Total lines processed: #{@lines_processed}"
          end
        end
      end
    end
  end
end

