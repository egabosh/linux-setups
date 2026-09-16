import re

path = "/app/backend/open_webui/routers/images.py"
with open(path) as f:
    src = f.read()

anchor = """        async def load_url_image(data):
            if data.startswith('data:'):
                return data
"""

patch = """        async def load_url_image(data):
            if data.startswith('data:'):
                return data

            # If the URL (possibly hallucinated by the model) contains a UUID that
            # matches a local file, resolve it locally instead of fetching remotely.
            m = re.search(r"([0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12})", data)
            if m:
                candidate = m.group(1)
                file_response = await get_file_content_by_id(candidate, user)
                if isinstance(file_response, FileResponse) and file_response.path.is_file():
                    async with aiofiles.open(file_response.path, 'rb') as f:
                        file_bytes = await f.read()
                    image_data = base64.b64encode(file_bytes).decode('utf-8')
                    mime_type, _ = mimetypes.guess_type(file_response.path)
                    return f'data:{mime_type};base64,{image_data}'
"""

if anchor in src and "hallucinated by the model" not in src:
    src = src.replace(anchor, patch)
    print("UUID PATCH applied")
else:
    print("UUID PATCH already present or anchor missing")

log_old = """    except Exception as e:
        error = e
        if isinstance(e, aiohttp.ClientResponseError):
            error = e.message

        raise HTTPException(status_code=400, detail=ERROR_MESSAGES.DEFAULT(error))"""

log_new = """    except Exception as e:
        error = e
        if isinstance(e, aiohttp.ClientResponseError):
            error = e.message
        log.exception('edit_image failed: %s', error)

        raise HTTPException(status_code=400, detail=ERROR_MESSAGES.DEFAULT(error))"""

if log_old in src:
    src = src.replace(log_old, log_new)
    print("LOG PATCH applied")
else:
    print("LOG PATCH already present or pattern missing")

with open(path, "w") as f:
    f.write(src)