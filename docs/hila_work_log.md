### 23.11.2025
- Continued implementation of data memory (d_mem)
- Created issue 
#14 for testbench development
- Q: why do we need tb for each module?

- להוסיף לREADME אחרי שאני עושה PULL את הקטע שהמעבד תומך גדלים שונים של זיכרון ואפשר לשנות את הפרמטרים בהתאם
- לכתוב שמשתמשים בAI לכתיבת המעבד לקיצור תהליכים?
- להוסיף איך מריצים מודול
vlog +incdir+source/common source/d_mem/d_mem_Word_Aligned_Block_RAM2.sv verif/d_mem_tb.sv

- vsim work.mem_tb

