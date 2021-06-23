module Import
  module Helpers
    module Brca
      module Providers
        module R0a
          module R0aConstants
            PASS_THROUGH_FIELDS_COLO = %w[age consultantcode servicereportidentifier providercode
                                          authoriseddate requesteddate practitionercode
                                          genomicchange specimentype].freeze

            BRCA_GENES_REGEX = /(?<brca>BRCA1|
                                       BRCA2|
                                       ATM|
                                       CHEK2|
                                       PALB2|
                                       MLH1|
                                       MSH2|
                                       MSH6|
                                       MUTYH|
                                       SMAD4)/xi.freeze
            DO_NOT_IMPORT = ['CYSTIC FIBROSIS GENETIC ANALYSIS REPORT',
                             '**ANY TEXT** ANALYSIS REPORT',
                             'APC/MUTYH MUTATION SCREENING REPORT,',
                             'Familial Adenomatous Polyposis Coli Confirmatory Testing Report',
                             'FAMILIAL ADENOMATOUS POLYPOSIS COLI PREDICTIVE TESTING REPORT',
                             'FRAGILE X SYNDROME GENETIC ANALYSIS REPORT',
                             'HNPCC (MSH6) MUTATION SCREENING REPORT',
                             'HNPCC CONFIRMATORY TESTING REPORT',
                             'HNPCC MUTATION SCREENING REPORT',
                             'HNPCC PREDICTIVE REPORT',
                             'HNPCC PREDICTIVE TESTING REPORT',
                             'LYNCH SYNDROME (@gene) - PREDICTIVE TESTING REPORT',
                             'LYNCH SYNDROME (hMSH6) MUTATION SCREENING REPORT',
                             'LYNCH SYNDROME (MLH1) - PREDICTIVE TESTING REPORT',
                             'LYNCH SYNDROME (MLH1/MSH2) MUTATION SCREENING REPORT',
                             'LYNCH SYNDROME (MSH2) - PREDICTIVE TESTING REPORT',
                             'LYNCH SYNDROME (MSH6) DOSAGE ANALYSIS REPORT',
                             'LYNCH SYNDROME (MSH6) MUTATION SCREENING REPORT',
                             'LYNCH SYNDROME CONFIRMATORY TESTING REPORT',
                             'LYNCH SYNDROME GENE SCREENING REPORT',
                             'LYNCH SYNDROME MUTATION SCREENING REPORT',
                             'METABOLIC VARIANT TESTING REPORT: @gene',
                             'MLH1/MSH2/MSH6 GENETIC TESTING REPORT',
                             'MSH6 DOSAGE ANALYSIS REPORT',
                             'MUTYH ASSOCIATED POLYPOSIS PREDICTIVE TESTING REPORT',
                             'RARE DISEASE SERVICE - MUTATION CONFIRMATION REPORT',
                             'RARE DISEASE SERVICE - PREDICTIVE TESTING REPORT',
                             'RETINAL DYSTROPHY MUTATION ANALYSIS REPORT',
                             'RETINOBLASTOMA MUTATION SCREENING REPORT',
                             'RETINOBLASTOMA LINKAGE REPORT',
                             'SEGMENTAL OVERGROWTH SYNDROME SCREENING REPORT',
                             'SOMATIC CANCER NGS PANEL TESTING REPORT',
                             'TUMOUR BRCA1/BRCA2 MUTATION ANALYSIS',
                             'ZYGOSITY TESTING REPORT',
                             'BRCA 1 Unclassified Variant Loss of Heterozygosity Studies from Archive Material'
                            ].freeze

            MOLTEST_MAP = {
              'HNPCC (hMSH6) MUTATION SCREENING REPORT'              => 'MSH6',
              'HNPCC (MSH6) MUTATION SCREENING REPORT'               => 'MSH6',
              'HNPCC CONFIRMATORY TESTING REPORT'                    => %w[MLH1 MSH2 MSH6],
              'HNPCC MSH2 c.942+3A>T MUTATION TESTING REPORT'        => 'MSH2',
              'HNPCC MUTATION SCREENING REPORT'                      => %w[MLH1 MSH2],
              'HNPCC PREDICTIVE REPORT'                              => %w[MLH1 MSH2 MSH6],
              'HNPCC PREDICTIVE TESTING REPORT'                      => %w[MLH1 MSH2 MSH6],
              'LYNCH SYNDROME (@gene) - PREDICTIVE TESTING REPORT'   => %w[MLH1 MSH2 MSH6],
              'LYNCH SYNDROME (hMSH6) MUTATION SCREENING REPORT'     => 'MSH6',
              'LYNCH SYNDROME (MLH1) - PREDICTIVE TESTING REPORT'    => %w[MLH1 MSH2 MSH6],
              'LYNCH SYNDROME (MLH1/MSH2) MUTATION SCREENING REPORT' => %w[MLH1 MSH2],
              'LYNCH SYNDROME (MSH2) - PREDICTIVE TESTING REPORT'    => 'MSH2',
              'LYNCH SYNDROME (MSH6) - PREDICTIVE TESTING REPORT'    => 'MSH6',
              'LYNCH SYNDROME (MSH6) MUTATION SCREENING REPORT'      => 'MSH6',
              'LYNCH SYNDROME CONFIRMATORY TESTING REPORT'           => %w[MLH1 MSH2 MSH6],
              'LYNCH SYNDROME GENE SCREENING REPORT'                 => %w[MLH1 MSH2 MSH6],
              'LYNCH SYNDROME MUTATION SCREENING REPORT'             => %w[MLH1 MSH2 MSH6],
              'LYNCH SYNDROME SCREENING REPORT'                      => %w[MLH1 MSH2 MSH6],
              'MLH1/MSH2/MSH6 GENE SCREENING REPORT'                 => %w[MLH1 MSH2 MSH6],
              'MLH1/MSH2/MSH6 GENETIC TESTING REPORT'                => %w[MLH1 MSH2 MSH6],
              'MSH6 PREDICTIVE TESTING REPORT'                       => 'MSH6',
              'RARE DISEASE SERVICE - PREDICTIVE TESTING REPORT'     => %w[MLH1 MSH2 MSH6],
              'VARIANT TESTING REPORT'                               => %w[MLH1 MSH2 MSH6]
            }.freeze

            MOLTEST_MAP_DOSAGE = {
              'HNPCC DOSAGE ANALYSIS REPORT'                               => %w[MLH1 MSH2 MSH6],
              'MSH6  DOSAGE ANALYSIS REPORT'                               => 'MSH6',
              'LYNCH SYNDROME DOSAGE ANALYSIS REPORT'                      => %w[MLH1 MSH2 MSH6],
              'LYNCH SYNDROME DOSAGE ANALYSIS - PREDICTIVE TESTING REPORT' => %w[MLH1 MSH2 MSH6],
              'LYNCH SYNDROME (MSH6) DOSAGE ANALYSIS REPORT'               => 'MSH6'
            }.freeze

            CDNA_REGEX = /c\.(?<cdna>[0-9]+[a-z]+>[a-z]+)|
                         c\.(?<cdna>[0-9]+.[0-9]+[a-z]+>[a-z]+)|
                         c\.(?<cdna>[0-9]+_[0-9]+[a-z]+)|
                         c\.(?<cdna>[0-9]+[a-z]+)|
                         c\.(?<cdna>.+\s[a-z]>[a-z])|
                         c\.(?<cdna>[0-9]+_[0-9]+\+[0-9]+[a-z]+)|
                         c\.(?<cdna>[0-9]+-[0-9]+_[0-9]+[a-z]+)|
                         c\.(?<cdna>[0-9]+\+[0-9]+_[0-9]+\+[0-9]+[a-z]+)|
                         c\.(?<cdna>-[0-9]+[a-z]+>[a-z]+)|
                         c\.(?<cdna>[0-9]+-[0-9]+_[0-9]+-[0-9]+[a-z]+)/ix.freeze

            PROT_REGEX = /p\.(\()?(?<impact>[a-z]+[0-9]+[a-z]+)(\))?/i.freeze
            EXON_REGEX = /(?<insdeldup>ins|del|dup)/i.freeze
            EXON_LOCATION_REGEX = /ex(?<exon>\d+)(.\d+)?(\sto\s)?(ex(?<exon2>\d+))?/i.freeze
          end
        end
      end
    end
  end
end
