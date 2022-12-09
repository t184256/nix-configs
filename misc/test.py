import sys  # <- italics
import sys  # ! imported more than once
import os  # ! not accessed

s = f'a {sys} c'  # sys isn't highlighted as string, nvim-treesitter#3634

class A:  # ! E302 2 blank lines
    long_prefix_a, long_prefix_b = 1, 2


A(x  # !! expected no arguments + x is not defined
 )  # ! E124 closing bracket does not match

sys.nonex  # ! not a known member
#   ^^^^^ underline

import re  # E402 import not at top
re.sub('s', r'a([b-c])', '\1')

print('a\n\x00')  # no italics for print, special characters stand out

x = 5678901234567890123456789012345678901234567890123456789012345678901234567890
#                                    the zero above is underlined and redd-ish ^

###

print(file=sys.stderr)

# test autocomplete here. no auto,
# first Tab opens menu, second completes common prefix, third+ selects entries
A().l

# test snippets here
__main__

# test hints here
print(file=
