# push
sui client publish --gas-budget 100000000


# mint

 sui client call --gas-budget 100000000 \
 --package  0x2 \
 --module coin \
 --function mint_and_transfer \
 --type-args '0xb1809901e295469e1254ba745b2bac6cd15d443d3585ae8b9a347e9550bc883a::rmb::RMB' \
 --args 0xed52afc120dba025d1e2fde4a94c466df632ef7da41e8f597bebbbd4ff517287 100000000000 0xff71ff2dfa9f5ba0176fb40fdda9d13d738ec97143b46bdfa1addc09e2263b02


  sui client call --gas-budget 100000000 \
  --package  0x2 \
  --module coin \
  --function mint_and_transfer \
  --type-args '0xb1809901e295469e1254ba745b2bac6cd15d443d3585ae8b9a347e9550bc883a::hk::HK' \
  --args 0x0bfc4ae88d4b8e153952453af2e1195de5ef00d4b78720f6a2d92108146bceb9 100000000000 0xff71ff2dfa9f5ba0176fb40fdda9d13d738ec97143b46bdfa1addc09e2263b02