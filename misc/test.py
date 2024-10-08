import sys  # normal font
import sys  # ! imported more than once
import os  # ! not accessed

s = f'''
a {sys} c
'''  # sys isn't highlighted as string

class A:  # ! E302 2 blank lines
    long_prefix_a, long_prefix_b = 1, 2


A(x  # !! expected no arguments + x is not defined
 )  # ! E124 closing bracket does not match

sys.nonex  # ! not a known member
#   ^^^^^ underline
# TODO <- colored (broken)

import re  # E402 import not at top
re.sub('s', r'a([b-c])', '\1')  # no italics

print('a\n\x00')  # no italics for print, special characters stand out

x = 5678901234567890123456789012345678901234567890123456789012345678901234567890
#                           (broken) the zero above is underlined and redd-ish ^

###

# test autocomplete here. no auto, must suggest long_prefix_a/long_prefix_b
# first Tab opens menu, second completes common prefix, third+ selects entries
# snippets and buffer completions don't show up
A().l

# test type validation
'a' / 2  # error
a: int = 'str'  # error

# test snippets with __main__
# test hints with print(file=
