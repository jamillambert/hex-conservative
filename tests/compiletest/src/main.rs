use hex::buf_encoder::BufEncoder;
use hex::Case;

fn main() { odd_buffer(); }

// This should fail to compile because the capacity size is odd.
fn odd_buffer() { let _encoder = BufEncoder::<2>::new(Case::Lower); }
