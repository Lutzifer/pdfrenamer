%W(2026).each do |year|
 %W(A B C D).each do |identifier|
   (1..64).each do |number|
 	padded_number = sprintf("%03d", number)
 	puts "\\normalsize{#{identifier}-#{year}-#{padded_number}} \\qrcode{doc-id:#{identifier}-#{year}-#{padded_number}}"
 	puts ""
   end
 end
end