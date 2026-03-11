import re

with open('/Users/golfzon/Desktop/devtool/devtool/ToolView/ColorPickerToolView.swift', 'r') as f:
    lines = f.readlines()

# find index of MARK: - Inspector
idx = -1
for i, line in enumerate(lines):
    if '// MARK: - Inspector (Preview Sidebar)' in line:
        idx = i
        break

if idx != -1:
    # Fix the missing brace before idx
    # The lines right before idx are:
    #             .padding(12)
    #         }
    #         
    # So we ensure there is an extra '    }' before the empty line
    out_lines = lines[:idx]
    
    # Check if '    }' is missing
    if out_lines[-2].strip() == '}':
        out_lines.insert(idx - 1, '    }\n')
    
    # Process the rest
    for line in lines[idx:]:
        if line.startswith('    '):
            out_lines.append(line[4:])
        else:
            out_lines.append(line)
            
    # remove the extra brace at the end of the file
    while out_lines[-1].strip() == '}':
        out_lines.pop()
    
    out_lines.append('}\n')
    
    with open('/Users/golfzon/Desktop/devtool/devtool/ToolView/ColorPickerToolView.swift', 'w') as f:
        f.writelines(out_lines)
