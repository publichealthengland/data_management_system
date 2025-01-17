module Export
  # Export and de-pseudonymise congenital anomalies (CARA) births extract
  # Specification in plan.io #18114
  class CongenitalAnomaliesBirthsFile < BirthFileSimple
    private

    # List of MBIS birth fields needed (for NHSD migration)
    # Copy of fields - ['patientid'], and replacing 'dobm_iso' with 'dobm' and 'dob_iso' with 'dob'
    RAW_FIELDS_USED = (
      (1..20).collect { |i| "icdpv_#{i}" } +
        (1..20).collect { |i| "icdpvf_#{i}" } +
        %w[fnamch1 fnamch2 fnamch3 fnamchx_1 snamch nhsno addrmt cestrss nhsind pcdpob pobt
           esttypeb namemaid dobm dob pcdrm fnamm_1 fnammx_1 snamm
           birthwgt multbth multtype sbind] +
        (1..20).collect { |i| "cod10r_#{i}" } +
        %w[deathlab wigwo10 sex empsecm empstm soc2km soc90m gestatn] +
        (1..5).collect { |i| "codfft_#{i}" } + %w[ctrypobm]
    ).freeze

    # Fields to extract
    def fields
      (1..20).collect { |i| "icdpv_#{i}" } +
        (1..20).collect { |i| "icdpvf_#{i}" } +
        %w[fnamch1 fnamch2 fnamch3 fnamchx_1 snamch nhsno addrmt cestrss nhsind pcdpob pobt
           esttypeb namemaid dobm_iso dob_iso pcdrm fnamm_1 fnammx_1 snamm
           birthwgt multbth multtype sbind] +
        (1..20).collect { |i| "cod10r_#{i}" } +
        %w[deathlab wigwo10 sex empsecm empstm soc2km soc90m gestatn] +
        (1..5).collect { |i| "codfft_#{i}" } + %w[ctrypobm] +
        %w[patientid] # Matched record id
    end

    # Emit the value for a particular field, including common field mappings
    # (May be extended by subclasses for extract-specific tweaks)
    def extract_field(ppat, field)
      val = super(ppat, field)
      case field
      when 'ctrypobf', 'ctrypobm'
        # Add missing leading zeros to country codes fields
        val = format('%03<val>d', val: val.to_i) if /\A[0-9]{1,2}\z/.match?(val)
      end
      val
    end
  end
end
