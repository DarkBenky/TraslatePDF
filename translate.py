import os
import time
import pdfplumber
from docx import Document
from transformers import AutoTokenizer, AutoModelForSeq2SeqLM

model_name = "facebook/nllb-200-distilled-600M"
tokenizer = AutoTokenizer.from_pretrained(model_name)
model = AutoModelForSeq2SeqLM.from_pretrained(model_name)

src_text = "Hello, how are you?"
# Fix: Remove src_lang parameter and set source language in tokenizer
tokenizer.src_lang = "eng_Latn"
tokens = tokenizer(src_text, return_tensors="pt")
generated = model.generate(**tokens, forced_bos_token_id=tokenizer.convert_tokens_to_ids("slk_Latn"))
print(tokenizer.decode(generated[0], skip_special_tokens=True))

def extract_text_from_docx(docx_path):
    """Extract text from DOCX file directly"""
    results = []
    doc = Document(docx_path)
    
    for para_num, paragraph in enumerate(doc.paragraphs, start=1):
        if paragraph.text.strip():  # Skip empty paragraphs
            results.append({
                "text": paragraph.text.strip(),
                "bbox": None,  # DOCX doesn't have bbox info
                "page": para_num  # Use paragraph number as page reference
            })
    return results

def extract_text_with_layout(pdf_path, merge_threshold=10):
    results = []
    with pdfplumber.open(pdf_path) as pdf:
        for page_num, page in enumerate(pdf.pages, start=1):
            words = page.extract_words()
            if not words:
                continue
            
            # Group words into lines/phrases
            current_group = {
                "text": words[0]["text"],
                "bbox": (words[0]["x0"], words[0]["top"], words[0]["x1"], words[0]["bottom"]),
                "page": page_num,
                "words": [words[0]]
            }
            
            for word in words[1:]:
                # Check if word is close enough to current group (same line or nearby)
                prev_word = current_group["words"][-1]
                
                # Merge if words are on same line (similar y-coordinates) and close horizontally
                if (abs(word["top"] - prev_word["top"]) <= merge_threshold and 
                    word["x0"] - prev_word["x1"] <= merge_threshold * 2):
                    
                    # Extend the group
                    current_group["text"] += " " + word["text"]
                    current_group["bbox"] = (
                        min(current_group["bbox"][0], word["x0"]),
                        min(current_group["bbox"][1], word["top"]),
                        max(current_group["bbox"][2], word["x1"]),
                        max(current_group["bbox"][3], word["bottom"])
                    )
                    current_group["words"].append(word)
                else:
                    # Save current group and start new one
                    results.append({
                        "text": current_group["text"],
                        "bbox": current_group["bbox"],
                        "page": current_group["page"]
                    })
                    
                    current_group = {
                        "text": word["text"],
                        "bbox": (word["x0"], word["top"], word["x1"], word["bottom"]),
                        "page": page_num,
                        "words": [word]
                    }
            
            # Don't forget the last group
            if current_group:
                results.append({
                    "text": current_group["text"],
                    "bbox": current_group["bbox"],
                    "page": current_group["page"]
                })
    
    return results

# === USAGE ===
docx_file = "User manual ProfileManagerWeb_v4.3.301 ENG.docx"  # Your .docx file

# Load the original document
doc = Document(docx_file)

count = 0
total_paragraphs = len([p for p in doc.paragraphs if p.text.strip()])
start_time = time.time()

print(f"Starting translation of {total_paragraphs} paragraphs...")

for paragraph in doc.paragraphs:
    if paragraph.text.strip():  # Only process non-empty paragraphs
        # Calculate progress and time estimates
        current_time = time.time()
        elapsed_time = current_time - start_time
        
        if count > 0:
            avg_time_per_paragraph = elapsed_time / count
            remaining_paragraphs = total_paragraphs - count
            estimated_remaining_time = remaining_paragraphs * avg_time_per_paragraph
            
            # Format time estimates
            elapsed_mins = int(elapsed_time // 60)
            elapsed_secs = int(elapsed_time % 60)
            remaining_mins = int(estimated_remaining_time // 60)
            remaining_secs = int(estimated_remaining_time % 60)
            
            print(f"Progress {count}/{total_paragraphs} | Elapsed: {elapsed_mins:02d}:{elapsed_secs:02d} | Est. remaining: {remaining_mins:02d}:{remaining_secs:02d}")
        else:
            print(f"Progress {count}/{total_paragraphs} | Starting...")
        
        count += 1
        
        original_text = paragraph.text.strip()
        print(f"[Para {count}] {original_text}")
        
        # Translate the text from English to Slovak
        tokenizer.src_lang = "slk_Latn"  # Set source language to English
        tokens = tokenizer(original_text, return_tensors="pt")
        generated = model.generate(**tokens, forced_bos_token_id=tokenizer.convert_tokens_to_ids("eng_Latn"))
        translated_text = tokenizer.decode(generated[0], skip_special_tokens=True)
        print(f"Translated: {translated_text}")
        
        # Clear the paragraph and add translated text while preserving formatting
        # Save the original formatting
        runs = paragraph.runs
        if runs:
            # Keep the first run's formatting and clear all runs
            first_run_format = runs[0]._element
            paragraph.clear()
            
            # Add the translated text with original formatting
            new_run = paragraph.add_run(translated_text)
            # Copy formatting from the first run
            if hasattr(first_run_format, 'rPr') and first_run_format.rPr is not None:
                new_run._element.rPr = first_run_format.rPr
        else:
            # If no runs, just replace the text
            paragraph.text = translated_text
        
        print("-" * 40)

# Final time summary
total_time = time.time() - start_time
total_mins = int(total_time // 60)
total_secs = int(total_time % 60)

# Save the translated document with a new name
output_filename = "User_manual_ProfileManagerWeb_v4.3.301_ENG.docx"
doc.save(output_filename)
print(f"Translated document saved as: {output_filename}")
