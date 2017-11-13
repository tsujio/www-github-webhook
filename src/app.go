package main

import (
	"log"
	"net/http"
	"os"
	"fmt"
	"encoding/json"
	"io/ioutil"
	"crypto/hmac"
	"crypto/sha1"
	"os/exec"
)

const script = "/app/script/restart-container.sh"

func sendError(w http.ResponseWriter, code int) {
	http.Error(w, http.StatusText(code), code)
}

func main() {
	secret := os.Getenv("WEBHOOK_SECRET")

	// Handle request by webhook
	http.HandleFunc("/", func(w http.ResponseWriter, r *http.Request) {
		// Check method
		if r.Method != "POST" {
			sendError(w, http.StatusMethodNotAllowed)
			return
		}

		// Check Content-Type
		contentType, ok := r.Header["Content-Type"]
		if !ok {
			log.Println("Header 'Content-Type' not found")
			sendError(w, http.StatusBadRequest)
			return
		}
		if contentType[0] != "application/json" {
			log.Printf("Unexpected Content-Type: expected=application/json " +
				"actual=%v\n", contentType[0])
			sendError(w, http.StatusBadRequest)
			return
		}

		// Check X-Github-Event
		xGithubEvent, ok := r.Header["X-Github-Event"]
		if !ok {
			log.Println("Header 'X-Github-Event' not found")
			sendError(w, http.StatusBadRequest)
			return
		}
		if xGithubEvent[0] != "push" {
			log.Printf("Unexpected X-Github-Event: expected=push actual=%v\n",
				xGithubEvent[0])
			sendError(w, http.StatusBadRequest)
			return
		}

		// Read request body
		body, err := ioutil.ReadAll(r.Body)
		if err != nil {
			log.Print(err)
			sendError(w, http.StatusBadRequest)
			return
		}

		// Check signature
		xHubSignature, ok := r.Header["X-Hub-Signature"]
		if !ok {
			log.Println("Header 'X-Hub-Signature' not found")
			sendError(w, http.StatusBadRequest)
			return
		}
		signature := xHubSignature[0][5:len(xHubSignature[0])]
		mac := hmac.New(sha1.New, []byte(secret))
		mac.Write(body)
		sum := fmt.Sprintf("%x", mac.Sum(nil))
		if signature != sum {
			log.Printf("Signature mismatch: header=%v calculated=%v\n",
				signature, sum)
			sendError(w, http.StatusBadRequest)
			return
		}

		// Parse payload
		var content struct {
			Repository struct {
				Name string `json:"name"`
			} `json:"repository"`
		}
		if err := json.Unmarshal(body, &content); err != nil {
			log.Printf("Cannot parse payload (%v): %v\n", err, string(body))
			sendError(w, http.StatusBadRequest)
			return
		}

		// Exec command with repository name
		cmd := exec.Command(script, content.Repository.Name)
		output, err := cmd.CombinedOutput()
		if err != nil {
			log.Printf("Failed to exec script (%v): %v\n", err, string(output))
			sendError(w, http.StatusBadRequest)
			return
		}

		log.Println(string(output))
		fmt.Fprintf(w, http.StatusText(http.StatusOK))
	})

	// Start application
	port := os.Getenv("ACTIVITY_PORT")
	if port == "" {
		port = "80"
	}
	log.Fatal(http.ListenAndServe(":" + port, nil))
}
