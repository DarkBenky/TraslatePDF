import os
import pdfplumber
from docx2pdf import convert
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

def convert_docx_to_pdf(docx_path, output_dir="."):
    pdf_path = os.path.join(output_dir, os.path.splitext(os.path.basename(docx_path))[0] + ".pdf")
    convert(docx_path, output_dir)
    return pdf_path

def extract_text_with_layout(pdf_path):
    results = []
    with pdfplumber.open(pdf_path) as pdf:
        for page_num, page in enumerate(pdf.pages, start=1):
            for word in page.extract_words():
                results.append({
                    "text": word["text"],
                    "bbox": (word["x0"], word["top"], word["x1"], word["bottom"]),
                    "page": page_num
                })
    return results

# === USAGE ===
# docx_file = "example.docx"  # Your .docx file
pdf_file = "example.pdf"  # Optional: if you already have a PDF file
# output_pdf = convert_docx_to_pdf(docx_file)
data = extract_text_with_layout(pdf_file)

for item in data:
    print(f"[Page {item['page']}] {item['text']} -> BBox: {item['bbox']} -> Text : {item['text']}")
    # translate the slovak text to English
    tokenizer.src_lang = "slk_Latn"  # Set source language to Slovak
    tokens = tokenizer(item['text'], return_tensors="pt")
    generated = model.generate(**tokens, forced_bos_token_id=tokenizer.convert_tokens_to_ids("eng_Latn"))
    translated_text = tokenizer.decode(generated[0], skip_special_tokens=True)
    print(f"Translated: {translated_text}")
    print("-" * 40)
