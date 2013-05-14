module Genealogy
  module Methods
    extend ActiveSupport::Concern

    ##################################################################
    ## linking methods
    ##################################################################
    
    # parents 
    [:father, :mother].each do |parent|

      ## no-bang version
      # add method
      define_method "add_#{parent}" do |relative|
        raise IncompatibleObjectException, "Linked objects must be instances of the same class: got #{relative.class} for #{self.class}" unless relative.is_a? self.class
        incompatible_parents = self.offspring | self.siblings.to_a | [self] 
        raise IncompatibleRelationshipException, "#{relative} can't be #{parent} of #{self}" if incompatible_parents.include? relative
        raise WrongSexException, "Can't add a #{relative.sex} #{parent}" unless (parent == :father and relative.is_male?) or (parent == :mother and relative.is_female?)
        send("#{parent}=",relative) == relative
      end
      
      # remove method
      define_method "remove_#{parent}" do
        send("#{parent}=",nil).nil?
      end

      # bang version
      # add method
      define_method "add_#{parent}!" do |relative|
        send("add_#{parent}",relative)
        save!
      end

      # remove method
      define_method "remove_#{parent}!" do 
        send("remove_#{parent}")
        save!
      end

    end

    # grandparents
    grandparents_lineage_name = { :father => :paternal, :mother => :maternal }
    [:father, :mother].each do |parent|
      [:father, :mother].each do |grandparent|

        # no-bang version
        define_method "add_#{grandparents_lineage_name[parent]}_grand#{grandparent}" do |relative|
          raise LineageGapException, "#{self} doesn't have #{parent}" unless send(parent)
          raise IncompatibleRelationshipException, "#{self} can't be grand#{grandparent} of itself" if relative == self
          send(parent).send("add_#{grandparent}",relative)
        end

        # bang version
        define_method "add_#{grandparents_lineage_name[parent]}_grand#{grandparent}!" do |relative|
          send("add_#{grandparents_lineage_name[parent]}_grand#{grandparent}",relative)
          send(parent).save!
        end

      end
    end

    ## add siblings
    # no bang version
    def add_siblings(sibs)
      raise LineageGapException, "Can't add siblings if both parents are nil" unless father and mother
      raise IncompatibleRelationshipException, "Can't add an ancestor as sibling" unless (ancestors.to_a & [sibs].flatten).empty?
      results = []
      [sibs].flatten.each do |sib|
        results << sib.add_father(self.father)
        results << sib.add_mother(self.mother)
      end
      results.inject(true){|memo,r| memo &= r}
    end

    # bang version
    def add_siblings!(sibs)
      transaction do
        add_siblings(sibs)
        [sibs].flatten.each { |s| s.save! }
        save!
      end
    end

    ##################################################################
    ## query methods
    ##################################################################
    
    def parents
      if father or mother
        [father,mother]
      else
        nil
      end
    end

    # grandparents
    [:father, :mother].each do |parent|
      [:father, :mother].each do |grandparent|

        define_method "#{grandparents_lineage_name[parent]}_grand#{grandparent}" do
          raise LineageGapException, "#{self} doesn't have #{parent}" unless send(parent)
          send(parent).send(grandparent)
        end

      end
    end

    def ancestors
      result = []
      remaining = parents.to_a.compact
      until remaining.empty?
        result << remaining.shift
        remaining += result.last.parents.to_a.compact
      end
      result.uniq
    end

    def offspring
      case sex
      when sex_male_value
        self.class.find_all_by_father_id(id)
      when sex_female_value
        self.class.find_all_by_mother_id(id)
      end
    end

    def descendants
      result = []
      remaining = offspring.to_a.compact
      until remaining.empty?
        result << remaining.shift
        remaining += result.last.offspring.to_a.compact
      end
      result.uniq
    end


    def siblings
      if father and mother
        (father.offspring & mother.offspring) - [self]
      end
    end

    def half_siblings
      if father and mother
        (father.offspring | mother.offspring) - [self] - siblings
      end
    end

    def is_female?
      sex == sex_female_value
    end

    def is_male?
      sex == sex_male_value  
    end

    module ClassMethods
    end

  end
end