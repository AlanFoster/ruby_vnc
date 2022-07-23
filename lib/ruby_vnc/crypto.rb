# frozen_string_literal: true

autoload :OpenSSL, 'openssl'

module RubyVnc::Crypto
  def self.des(challenge, password)
    # To form the key, the password is truncated
    # to eight characters, or padded with null bytes on the right
    truncated_password = password[0...8].ljust(8, "\x00")
    # Flip bits as per the errata
    # https://www.rfc-editor.org/errata_search.php?rfc=6143&rec_status=0
    # https://www.vidarholen.net/contents/junk/vnc.html
    key = [truncated_password.unpack1('B*').scan(/.{8}/).map(&:reverse).join].pack('B*')

    cipher = OpenSSL::Cipher.new('des')
    cipher.encrypt
    cipher.key = key

    result = ''.b
    2.times do |i|
      cipher.reset
      cipher.iv = "\x00".b * 8
      result << cipher.update(challenge[i * 8, 8])
    end

    result
  end
end
