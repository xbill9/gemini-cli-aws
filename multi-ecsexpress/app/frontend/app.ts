import './style.css';

const createForm = document.getElementById('create-form') as HTMLFormElement;
const topicInput = document.getElementById('topic-input') as HTMLInputElement;
const createButton = document.getElementById('create-button') as HTMLButtonElement;
const progressContainer = document.getElementById('progress-container') as HTMLElement;
const statusText = document.getElementById('status-text') as HTMLElement;

// Generate a random session ID for this browser session
const sessionId = 'session-' + Math.random().toString(36).substring(2, 15);

function showProgress() {
    console.log("Showing progress container...");
    createForm.classList.add('hidden');
    topicInput.disabled = true;
    createButton.disabled = true;
    createButton.innerHTML = 'Building...';
    progressContainer.classList.remove('hidden');
}

function updateStatus(text: string) {
    console.log("Status update:", text);
    statusText.textContent = text;
    
    // Simple logic to highlight steps based on text content
    document.querySelectorAll('.step').forEach(s => s.classList.remove('active'));
    
    if (text.toLowerCase().includes('research')) {
        document.getElementById('step-researcher')?.classList.add('active');
    } else if (text.toLowerCase().includes('judge') || text.toLowerCase().includes('evaluating')) {
        document.getElementById('step-judge')?.classList.add('active');
    } else if (text.toLowerCase().includes('writ') || text.toLowerCase().includes('build')) {
        document.getElementById('step-builder')?.classList.add('active');
    }
}

createForm.addEventListener('submit', async (e) => {
    e.preventDefault();
    const topic = topicInput.value.trim();
    if (!topic) return;

    console.log("Form submitted with topic:", topic);
    showProgress();

    try {
        console.log("Initiating fetch to /api/chat_stream...");
        const response = await fetch('/api/chat_stream', {
            method: 'POST',
            headers: {
                'Content-Type': 'application/json'
            },
            body: JSON.stringify({
                message: `Create a comprehensive course on: ${topic}`,
                session_id: sessionId
            })
        });

        console.log("Fetch response received. OK:", response.ok, "Status:", response.status);

        if (!response.ok) {
            throw new Error(`HTTP error! status: ${response.status}`);
        }

        const reader = response.body?.getReader();
        if (!reader) {
            console.error("No reader found in response body");
            throw new Error("No reader found");
        }
        
        console.log("Starting to read stream...");
        const decoder = new TextDecoder();
        let buffer = '';

        while (true) {
            const { value, done } = await reader.read();
            if (done) {
                console.log("Stream reader done.");
                break;
            }
            
            const chunk = decoder.decode(value, { stream: true });
            console.log("Received chunk:", chunk);
            buffer += chunk;
            const lines = buffer.split('\n');
            buffer = lines.pop() || '';

            for (const line of lines) {
                if (!line.trim()) continue;
                try {
                    const data = JSON.parse(line);
                    console.log("Parsed SSE event:", data);
                    if (data.type === 'progress') {
                        updateStatus(data.text);
                    } else if (data.type === 'result') {
                        console.log("Received result, length:", data.text.length);
                        // Save result and redirect
                        localStorage.setItem('currentCourse', data.text);
                        window.location.href = '/course.html';
                        return;
                    }
                } catch (e) {
                    console.error('Error parsing JSON from line:', line, e);
                }
            }
        }

    } catch (error) {
        console.error('Error during chat_stream:', error);
        statusText.textContent = 'Something went wrong: ' + (error as Error).message;
    }
});
