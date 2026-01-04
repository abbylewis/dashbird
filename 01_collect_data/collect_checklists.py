from playwright.sync_api import sync_playwright
from bs4 import BeautifulSoup
from collections import deque
import requests, os, pickle

USER_IDS = ['OTYxMTQ2', 'MjIyMTQxOA', 'NDYyODk2Mg', 'NDYyNzIwMQ']
PREV_LISTS_PICKLE_PATH = '01_collect_data/prev_lists.pickle'
DATA_DIRECTORY = '02_extracted_data'

# load secrets
EBIRD_PW = os.environ.get('EBIRD_PW')
EBIRD_API_KEY = os.environ.get('EBIRD_API_KEY')

# ensure that each user has a directory for their data
for id in USER_IDS:
    os.makedirs(f'{DATA_DIRECTORY}/{id}', exist_ok = True)

# load the last ten checklists collected
try:
    with open(PREV_LISTS_PICKLE_PATH, 'rb') as f:
        prev_lists = pickle.load(f)
except FileNotFoundError:
    prev_lists = {id: deque([], 10) for id in USER_IDS}

# Note: checklist IDs appear to sort in chronological order, by time of checklist creation
# (aka submission), not observation date. eBird profile pages appear to display the last ten
# submitted checklists, by observation date.

with sync_playwright() as p:

    # log into eBird so we can access public profiles
    browser = p.chromium.launch(headless = False)
    context = browser.new_context()
    page = context.new_page()
    page.goto('https://secure.birds.cornell.edu/cassso/login')
    page.get_by_role('textbox', name='Username').click()
    page.get_by_role('textbox', name='Username').fill('oatnewguo')
    page.get_by_role('textbox', name='Password').click()
    page.get_by_role('textbox', name='Password').fill(EBIRD_PW)
    page.get_by_role('button', name='Sign in').click()

    # get the ten most recent checklists from participants' profiles
    for user_id in USER_IDS:
        page.goto(f'https://ebird.org/profile/{user_id}', wait_until = 'networkidle')
        soup = BeautifulSoup(page.content(), 'html.parser')
        list_ids = [elem['href'].split('checklist/')[1] for elem in soup.find_all(attrs = {'class': 'FeedItem-main'})]

        # save new checklists that are not among the last ten collected
        new_list_ids = [id for id in list_ids if id not in prev_lists[user_id]]
        for list_id in new_list_ids:
            with open(f'{DATA_DIRECTORY}/{user_id}/{list_id}.json', 'w') as f:
                r = requests.get(f'https://api.ebird.org/v2/product/checklist/view/{list_id}',
                                 headers = {'X-eBirdApiToken': EBIRD_API_KEY})
                f.write(r.text)

        # update the last ten checklists collected
        for list_id in reversed(new_list_ids):
            prev_lists[user_id].append(list_id)
        with open(PREV_LISTS_PICKLE_PATH, 'wb') as f:
            pickle.dump(prev_lists, f)

    # ---------------------
    context.close()
    browser.close()