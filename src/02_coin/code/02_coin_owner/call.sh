# push
sui client publish --gas-budget 100000000


# mint

 sui client call --gas-budget 100000000 \
 --package  0x2 \
 --module coin \
 --function mint_and_transfer \
 --type-args '0x308cb19acc563ad8bee28674c64fedfc5c982a65f41385b7bea57d0dd5d01c8f::rmb::RMB' \
 --args 0xacf25cf93e4a014b979aaa9033776bf61e5838a36ddc3b22fb2213df63ef9a3c 1000000000 0xff71ff2dfa9f5ba0176fb40fdda9d13d738ec97143b46bdfa1addc09e2263b02