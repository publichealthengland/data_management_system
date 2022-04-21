module Import
  module Helpers
    module Brca
      module Providers
        module Rtd
          module RtdConstants
            TEST_SCOPE_MAP = { 'brca-ng'           => :full_screen,
                               'brca-rapid screen' => :full_screen,
                               'brca top up'       => :full_screen,
                               'brca-pred'         => :targeted_mutation,
                               'brca1'             => :targeted_mutation,
                               'brca2'             => :targeted_mutation }.freeze

            TEST_TYPE_MAP = { 'diag - symptoms' => :diagnostic,
                              'diagnosis' => :diagnostic,
                              'diagnostic' => :diagnostic,
                              'diagnostic test' => :diagnostic,
                              'diagnostic/forward' => :diagnostic,
                              '100,000 genomes project' => :diagnostic,
                              'presymptomatic' => :predictive,
                              'presymptomatic test' => :predictive,
                              'predictive' => :predictive,
                              'predictive test' => :predictive,
                              'prenatal diagnosis' => :prenatal }.freeze

            TEST_SCOPE_FROM_TYPE_MAP =   {  '100,000 genomes project' => :full_screen,
                                            'carrier' => :targeted_mutation,
                                            'carrier test' => :targeted_mutation,
                                            'diag - symptoms' => :full_screen,
                                            'diagnosis' => :full_screen,
                                            'diagnostic' => :full_screen,
                                            'diagnostic test' => :full_screen,
                                            'diagnostic/forward' => :full_screen,
                                            'family studies' => :targeted_mutation,
                                            'msi screen' => :no_genetictestscope,
                                            'predictive' => :targeted_mutation,
                                            'predictive test' => :targeted_mutation,
                                            'presymptomatic' => :targeted_mutation,
                                            'presymptomatic test' => :targeted_mutation,
                                            'storage' => :full_screen,
                                            'unknown' => :no_genetictestscope,
                                            'unknown / other' => :no_genetictestscope }.freeze

            PASS_THROUGH_FIELDS = %w[age authoriseddate
                                     requesteddate
                                     specimentype
                                     providercode
                                     consultantcode
                                     servicereportidentifier].freeze

            FIELD_NAME_MAPPINGS = { 'consultantcode'    => 'practitionercode',
                                    'ngs sample number' => 'servicereportidentifier' }.freeze

            PROTEIN_REGEX = /p\.\((?<impact>.+)\)|
                            \(p\.(?<impact>[A-Za-z]+.+)\)|
                            p\.(?<impact>[A-Za-z]+.+)/ix.freeze # Added by Francesco
            BRCA1_REGEX = /BRCA1/i.freeze
            BRCA2_REGEX = /BRCA2/i.freeze
            CDNA_REGEX = /c\.\*?(?<cdna>
                                ([0-9]+[a-z]+>[a-z]+)(.+)?|
                                [0-9]+_[0-9]+|
                                ([0-9]+.[0-9]+[a-z]+>[a-z]+)(.+)?|
                                ([0-9]+.[0-9]+[a-z]+)(.+)?|
                                [0-9]+[0-9]+[a-z]+|
                                [0-9]+[+>_-][0-9]+[+>_-][0-9]+[+>_-][0-9]+[ACGTdelinsup]+|
                                ([0-9]+.[0-9]+[a-z]+>[a-z]+)(.+)?)?/ix.freeze

            EXON_VARIANT_REGEX = /(?<variant>del|dup|ins).+ex(?<on>on)?(?<s>s)?\s
                                  (?<exons>[0-9]+(?<dgs>-[0-9]+)?)|
                                ex(?<on>on)?(?<s>s)?\s?(?<exons>[0-9]+(?<dgs>-[0-9]+)?)\s?
                                (?<variant>del|dup|ins)|
                                (?<variant>del|dup|ins)\sexon(?<s>s)?\s
                                (?<exons>[0-9]+(?<dgs>\sto\s[0-9]+))|
                                ex(on)?(s)?\s?(?<exons>[0-9]+\s?(\s?-\s?[0-9]+)?)\s?(?<variant>del|dup|ins)?|
                                (?<variant>del|dup|ins)(?<s>\s)?(?<exons>[0-9]+(?<dgs>-[0-9]+)?)|
                                ex(?<on>on)?(?<s>s)?\s(?<exons>[0-9]+(?<dgs>\sto\s[0-9]+)?)\s
                                (?<variant>del|dup|ins)|
                                x(?<exons>[0-9]+[-]?[0-9]+)\s?(?<variant>del|dup|ins)|
                                x(?<exons>[0-9]+[-]?[0-9]?)\s?(?<variant>del|dup|ins)/ix.freeze

            PATHOGENICITY_REGEX = /abnormal|Likely benign|Likely pathogenic|
                                  non-pathological variant|pathogenic|unclassified variant/ix.freeze
          end
        end
      end
    end
  end
end
