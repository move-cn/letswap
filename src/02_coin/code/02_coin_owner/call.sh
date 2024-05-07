# push
sui client publish --gas-budget 100000000


# mint

 sui client call --gas-budget 100000000 \
 --package  0x2 \
 --module coin \
 --function mint_and_transfer \
 --type-args '0x26758c3a1aa0c3bf388cf7d94c90bb46ab3668c7ad99add1acd5139424b93533::rmb::RMB' \
 --args 0xc4d306168ee191ce5102a1c723abd8e71840c569cc06df63f4945fa8e6c06903 100000000000 0xff71ff2dfa9f5ba0176fb40fdda9d13d738ec97143b46bdfa1addc09e2263b02


  sui client call --gas-budget 100000000 \
  --package  0x2 \
  --module coin \
  --function mint_and_transfer \
  --type-args '0x26758c3a1aa0c3bf388cf7d94c90bb46ab3668c7ad99add1acd5139424b93533::hk::HK' \
  --args 0xaee1414d10f4ca34780ad4d149d6eaf8fce0c8833da27e75dd6b0f8b769af9cb 100000000000 0xff71ff2dfa9f5ba0176fb40fdda9d13d738ec97143b46bdfa1addc09e2263b02