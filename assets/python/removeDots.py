#!/usr/bin/env python3
# -*- coding: utf-8 -*-
# reference: https://www.metmuseum.org/art/collection/search/454661
# reference: https://easyquran.com/en/stages-of-transcribing-of-the-holy-quran/
# reference: Ageless Qur'an Timeless Text: A Visual Study of Sura 17 Across 14 Centuries & 19 Manuscripts
# by Mohammad Mustafa al-Azami
"""
Script to map dotted Arabic letters to non-dotted versions.
"""

def map_to_non_dotted(text):
    """Map dotted Arabic characters to non-dotted versions."""
    # Mapping based on provided requirements
    mapping = {
        'ا': 'ا',  # Alif stays the same
        'ب': 'ٮ',  # Ba to dotless Ba
        'ت': 'ٮ',  # Ta to dotless Ba
        'ث': 'ٮ',  # Tha to dotless Ba
        'ج': 'ح',  # Jeem to Ha
        'ح': 'ح',  # Ha stays the same
        'خ': 'ح',  # Kha to Ha
        'د': 'د',  # Dal stays the same
        'ذ': 'د',  # Thal to Dal
        'ر': 'ر',  # Ra stays the same
        'ز': 'ر',  # Zay to Ra
        'س': 'س',  # Seen stays the same
        'ش': 'س',  # Sheen to Seen
        'ص': 'ص',  # Sad stays the same
        'ض': 'ص',  # Dad to Sad
        'ط': 'ط',  # Tah stays the same
        'ظ': 'ط',  # Zah to Tah
        'ع': 'ع',  # Ain stays the same
        'غ': 'ع',  # Ghain to Ain
        'ف': 'ڡ',  # Fa to dotless Fa
        'ق': 'ٯ',  # Qaf to dotless Qaf
        'ك': 'ك',  # Kaf stays the same
        'ل': 'ل',  # Lam stays the same
        'م': 'م',  # Meem stays the same
        'ن': 'ٮ',  # Noon to dotless Ba form (consistent for all positions)
        'ه': 'ه',  # Ha stays the same
        'و': 'و',  # Waw stays the same
        'ي': 'ى',  # Ya to Alif Maqsurah
        'ى': 'ى',  # Alif Maqsurah stays the same
        'ة': 'ه',  # Ta Marbuta to Ha
        # Also handle diacritics (remove them)
        'َ': '',  # Fatha
        'ُ': '',  # Damma
        'ِ': '',  # Kasra
        'ً': '',  # Tanween Fath
        'ٌ': '',  # Tanween Damm
        'ٍ': '',  # Tanween Kasr
        'ّ': '',  # Shadda
        'ْ': '',  # Sukun
        'ٰ': '',  # Superscript Alif
        'ٓ': '',  # Maddah
        'ء': '',  # Hamza
        'أ': 'ا',  # Hamza on Alif to Alif
        'إ': 'ا',  # Hamza below Alif to Alif
        'ؤ': 'و',  # Hamza on Waw to Waw
        'ئ': 'ى',  # Hamza on Ya to Alif Maqsurah
        'ـٔ': '',  # Hamza inside word (superscript/mini hamza)
    }
    
    result = ""
    for char in text:
        result += mapping.get(char, char)
    
    return result

def process_file(input_path, output_path):
    """Process the Quran file, converting all dotted characters to non-dotted."""
    with open(input_path, 'r', encoding='utf-8') as infile, \
         open(output_path, 'w', encoding='utf-8') as outfile:
        
        for line in infile:
            # Keep the verse numbering format (e.g., "1|1|")
            parts = line.strip().split('|', 2)
            if len(parts) >= 3:
                verse_num = parts[0] + '|' + parts[1] + '|'
                text = parts[2]
                # Map the actual text to non-dotted version
                text_no_dots = map_to_non_dotted(text)
                outfile.write(f"{verse_num}{text_no_dots}\n")
            else:
                # Just in case there are lines that don't match the expected format
                outfile.write(map_to_non_dotted(line))

if __name__ == "__main__":
    input_file = "Txt files/quran-uthmani-min (1).txt"
    output_file = "Txt files/quran-uthmani-nodots_mini.txt"
    
    try:
        process_file(input_file, output_file)
        print(f"Successfully converted dotted text to non-dotted version.")
        print(f"Output saved to: {output_file}")
    except Exception as e:
        print(f"An error occurred: {e}")
