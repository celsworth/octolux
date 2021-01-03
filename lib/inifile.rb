# frozen_string_literal: true

class IniFile
  class Parser
    def typecast(value)
      case value
      when /\Atrue\z/i then  true
      when /\Afalse\z/i then false
      when /\A\s*\z/i then   nil
      else
        # Monkey-patch to avoid converting contents of the inifile into
        # Integers or Floats. Just leave everything as Strings.
        unescape_value(value)
      end
    end
  end
end
