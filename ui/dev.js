// You can ignore this file. All it does is make the UI work on your browser.
window.addEventListener('load', () => {
    const phoneWrapper = document.getElementById('phone-wrapper');
    const app = phoneWrapper.querySelector('.app');

    if (window.invokeNative) {
        phoneWrapper.parentNode.insertBefore(app, phoneWrapper);
        phoneWrapper.parentNode.removeChild(phoneWrapper);
        return;
    }
    document.getElementById('phone-wrapper').style.display = 'block';
    document.body.style.visibility = 'visible';
    const previewParams = new URLSearchParams(window.location.search);
    document.documentElement.dataset.theme = previewParams.get('theme') === 'dark' ? 'dark' : 'light';
    const mockCanAdd = previewParams.get('role') !== 'viewer';
    const mockIsAdmin = !['viewer', 'boss'].includes(previewParams.get('role'));

    window.components = window.components || {
        setGallery(options) {
            const imageUrl = new URL('event-hero.webp', window.location.href).href;
            window.setTimeout(() => options?.onSelect?.({
                id: 'browser-preview-image',
                src: imageUrl,
                isVideo: false,
            }), 120);
        },
    };

    const localDate = (date) => {
        const pad = (value) => String(value).padStart(2, '0');
        return `${date.getFullYear()}-${pad(date.getMonth() + 1)}-${pad(date.getDate())}`;
    };
    const today = new Date();
    const upcomingPreview = previewParams.get('featured') === 'upcoming';
    const firstUpcomingDate = new Date(today);
    firstUpcomingDate.setDate(today.getDate() + 2);
    const nextEventDate = new Date(today);
    nextEventDate.setDate(today.getDate() + 5);
    const thirdUpcomingDate = new Date(today);
    thirdUpcomingDate.setDate(today.getDate() + 7);
    const mockEvents = [
        {
            id: 1,
            citizenid: 'preview-user',
            author: 'Felicity運営局',
            title: '夏祭りナイト 2026',
            event_date: localDate(upcomingPreview ? firstUpcomingDate : today),
            start_time: '20:00',
            end_time: '23:00',
            location: 'マーケット広場・ビーチエリア',
            description: '屋台やゲームコーナー、ライブステージに加えて花火大会も開催します。みんなで最高の夏の思い出を作ろう！',
            reminder_enabled: true,
            reminder_at: `${localDate(today)} 19:30`,
            reminder_minutes: 30,
            participant_count: 128,
            has_joined: 0,
            hide_author: 0,
        },
        {
            id: 2,
            citizenid: 'preview-user',
            author: 'City Music Club',
            title: 'サンセット・ライブ',
            event_date: localDate(nextEventDate),
            start_time: '18:30',
            end_time: '20:00',
            location: 'ビーチステージ',
            description: '夕暮れの海辺で楽しむアコースティックライブです。',
            reminder_enabled: false,
            reminder_at: null,
            participant_count: 34,
            has_joined: 1,
        },
        {
            id: 3,
            citizenid: 'preview-user',
            author: 'Night Drive Crew',
            title: 'ミッドナイト・ドライブ',
            event_date: localDate(upcomingPreview ? thirdUpcomingDate : today),
            start_time: '23:30',
            end_time: null,
            location: 'マーケット広場 集合',
            description: '夏祭りのあとに、街の夜景を巡るナイトドライブへ出発します。',
            reminder_enabled: false,
            reminder_at: null,
            participant_count: 18,
            has_joined: 0,
        },
    ];

    const sendMockEvents = () => window.postMessage({
        type: 'events',
        data: {
            events: mockEvents,
            citizenid: 'preview-user',
            canAdd: mockCanAdd,
            isAdmin: mockIsAdmin,
        },
    });

    window.fetchNui = window.fetchNui || ((eventName, data) => {
        if (eventName === 'getEvents') {
            window.setTimeout(sendMockEvents, 0);
        } else if (eventName === 'toggleParticipation') {
            const event = mockEvents.find((item) => item.id === Number(data?.id));
            if (event) {
                const joined = event.has_joined === true || Number(event.has_joined) === 1;
                event.has_joined = joined ? 0 : 1;
                event.participant_count = Math.max(0, Number(event.participant_count) + (joined ? -1 : 1));
                window.setTimeout(() => {
                    window.postMessage({
                        type: 'result',
                        data: {
                            ok: true,
                            message: joined ? '参加予約を取り消しました' : '参加予約が完了しました',
                        },
                    });
                    sendMockEvents();
                }, 180);
            }
        }
        return Promise.resolve({});
    });

    // Create the Frame element
    const createFrame = (children) => {
        const frame = document.createElement('div');
        frame.classList.add('phone-frame');

        // Create the phone notch (you can style it as needed)
        const notch = document.createElement('div');
        notch.classList.add('phone-notch');

        // Create the phone indicator
        const indicator = document.createElement('div');
        indicator.classList.add('phone-indicator');

        // Create the time
        const time = document.createElement('div');
        time.classList.add('phone-time');

        const date = new Date();
        time.innerText = date.getHours().toString().padStart(2, '0') + ':' + date.getMinutes().toString().padStart(2, '0');

        setInterval(() => {
            const date = new Date();
            time.innerText = date.getHours().toString().padStart(2, '0') + ':' + date.getMinutes().toString().padStart(2, '0');
        }, 1000);

        // Create the phone content container and append children to it
        const phoneContent = document.createElement('div');
        phoneContent.classList.add('phone-content');
        phoneContent.appendChild(children);

        // Append the notch and content to the frame
        frame.appendChild(notch);
        frame.appendChild(phoneContent);
        frame.appendChild(indicator);
        frame.appendChild(time);

        return frame;
    };

    const devWrapper = document.createElement('div');
    devWrapper.classList.add('dev-wrapper');

    const frame = createFrame(app);
    devWrapper.appendChild(frame);
    devWrapper.style.display = 'block';

    phoneWrapper.parentNode.insertBefore(devWrapper, phoneWrapper);
    phoneWrapper.parentNode.removeChild(phoneWrapper);

    window.postMessage('componentsLoaded');
    if (previewParams.get('view') === 'joined') {
        window.setTimeout(() => document.getElementById('nav-joined')?.click(), 80);
    }
    if (previewParams.get('slide') === 'next') {
        window.setTimeout(() => document.getElementById('featured-next')?.click(), 100);
    }
    if (['add', 'reminder', 'image', 'admin', 'time', 'time-set'].includes(previewParams.get('form'))) {
        window.setTimeout(() => document.getElementById('header-add')?.click(), 120);
    }
    if (previewParams.get('form') === 'reminder') {
        window.setTimeout(() => document.getElementById('f-reminder-enabled')?.click(), 180);
    }
    if (previewParams.get('form') === 'image') {
        window.setTimeout(() => document.getElementById('f-image-pick')?.click(), 200);
    }
    if (previewParams.get('form') === 'time') {
        window.setTimeout(() => document.getElementById('f-start-open')?.click(), 200);
    }
    if (previewParams.get('form') === 'time-set') {
        window.setTimeout(() => document.getElementById('f-start-open')?.click(), 200);
        window.setTimeout(() => document.querySelector('#time-hour-wheel [data-value="20"]')?.click(), 280);
        window.setTimeout(() => document.querySelector('#time-minute-wheel [data-value="0"]')?.click(), 340);
        window.setTimeout(() => document.getElementById('time-editor-apply')?.click(), 620);
    }
});
